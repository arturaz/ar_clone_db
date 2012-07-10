class ActiveRecord::Cloner
  # Clones DB structure from DB to which we can connect with  _source_config_
  # to DB to which we can connect with _target_config_. Wipes target DB!
  #
  # _changers_ is a Hash of: {table_name_as_symbol => [Proc, ...]}
  #
  # Each Proc gets called with single argument: SHOW CREATE TABLE sql string.
  # Its expected to return a modified version of that SQL string.
  #
  def self.clone_db(source_config, target_config, changers={}, verbose=true)
    if verbose
      puts "Cloning database..."
      puts "Source: #{source_config["database"]}"
      puts "Target: #{target_config["database"]}"
    end

    ActiveRecord::Base.establish_connection(source_config)

    # Get table data
    tables_to_clone = ActiveRecord::Base.connection.tables.reject do |table|
      table == 'schema_migrations'
    end

    puts "Tables: #{tables_to_clone.join(", ")}" if verbose

    tables = tables_to_clone.map do |table|
      res = ActiveRecord::Base.connection.select_one(
        "SHOW CREATE TABLE `#{table}`")
      sql = res["Create Table"]
      (changers[table.to_sym] || []).each do |changer|
        sql = changer.call(sql)
      end
      sql
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

    puts "Cloned." if verbose
  end
end
