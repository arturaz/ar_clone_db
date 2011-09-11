class ActiveRecord::Cloner
  # Clones DB structure from DB to which we can connect with  _source_config_
  # to DB to which we can connect with _target_config_. Wipes target DB!
  def self.clone_db(source_config, target_config)
    ActiveRecord::Base.establish_connection(source_config)

    # Get table data
    tables = []
    ActiveRecord::Base.connection.tables.reject do |table|
      table == 'schema_migrations'
    end.each do |table|
      res = ActiveRecord::Base.connection.select_one(
        "SHOW CREATE TABLE `#{table}`")
      sql = res["Create Table"]
      tables.push sql
    end

    ActiveRecord::Base.establish_connection(target_config)

    # Disable FK checks
    ActiveRecord::Base.connection.execute('SET foreign_key_checks = 0')

    # Drop existing tables
    ActiveRecord::Base.connection.tables.each do |table|
      ActiveRecord::Base.connection.execute("DROP TABLE `#{table}`")
    end

    # Create tables
    tables.each { |sql| ActiveRecord::Base.connection.execute(sql) }

    # Reenable FK checks
    ActiveRecord::Base.connection.execute('SET foreign_key_checks = 1')
  end
end
