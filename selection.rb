require 'sqlite3'

module Selection
  def find(*ids)

    if ids.length == 1
      find_one(ids.first)
    else
      rows = connection.execute <<-SQL
        SELECT #{columns.join ","} FROM #{table}
        WHERE id IN (#{ids.join(",")});
      SQL

      rows_to_array(rows)
    end
  end

  def find_one(id)
    row = connection.get_first_row <<-SQL
      SELECT #{columns.join ","} FROM #{table}
      WHERE id = #{id};
    SQL

    init_object_from_row(row)
  end

  def find_by(attribute, value)
    row = connection.get_first_row(
      "SELECT #{columns.join ","} FROM #{table} WHERE #{attribute} = ?;",
      BlocRecord::Utility.sql_strings(value)
    )

    init_object_from_row(row)
  end

  def take(num=1)
    if num > 1
      rows = connection.execute(
        "SELECT #{columns.join ","} FROM #{table} ORDER BY random() LIMIT ?;",
        num
      )

      rows_to_array(rows)
    else
      take_one
    end
  end

  def take_one
    row = connection.get_first_row <<-SQL
      SELECT #{columns.join ","} FROM #{table}
      ORDER BY random()
      LIMIT 1;
    SQL

    init_object_from_row(row)
  end

  def first
    row = connection.get_first_row <<-SQL
      SELECT #{columns.join ","} FROM #{table}
      ORDER BY id
      ASC LIMIT 1;
    SQL

    init_object_from_row(row)
  end

  def last
    row = connection.get_first_row <<-SQL
      SELECT #{columns.join ","} FROM #{table}
      ORDER BY id
      DESC LIMIT 1;
    SQL

    init_object_from_row(row)
  end

  def all
    rows = connection.execute <<-SQL
      SELECT #{columns.join ","} FROM #{table};
    SQL

    rows_to_array(rows)
  end

  def where(*args)
    if args.count > 1
      expression = args.shift
      params = args
    else
      case args.first
      when String
        expression = "?"
        params = args.first
      when Hash
        params = BlocRecord::Utility.convert_keys(args.first)
        expression = params.keys.map {|key| "#{key}=:#{key}"}.join(" and ")
      end
    end

    sql = <<-SQL
      SELECT #{columns.join ","} FROM #{table}
      WHERE #{expression};
    SQL

    rows = connection.execute(sql, params)
    rows_to_array(rows)
  end

  def order(*args)
    if args.count > 1
      order = args.join(",")
    else
      order = args.first.to_s
    end
    rows = connection.execute(
      "SELECT * FROM #{table} ORDER BY ?;",
      order
    )
    rows_to_array(rows)
  end

  def join(*args)
    if args.count > 1
      joins = args.map { |arg| "INNER JOIN #{arg} ON #{arg}.#{table}_id = #{table}.id"}.join(" ")
      rows = connection.execute <<-SQL
        SELECT * FROM #{table} #{joins}
      SQL
    else
      case args.first
      when String
        rows = connection.execute <<-SQL
          SELECT * FROM #{table} #{BlocRecord::Utility.sql_strings(args.first)};
        SQL
      when Symbol
        rows = connection.execute <<-SQL
          SELECT * FROM #{table}
          INNER JOIN #{args.first} ON #{args.first}.#{table}_id = #{table}.id
        SQL
      end
    end
    rows_to_array(rows)
  end

  def select(*fields)
    rows = connection.execute(
      "SELECT ? FROM #{table};",
      fields.join(", ")
    )
    collection = BlocRecord::Collection.new
    rows.each { |row| collection << new(Hash[fields.zip(row)]) }
    collection
  end

  def limit(value, offset=0)
    rows = connection.execute(
      "SELECT * FROM #{table} LIMIT ? OFFSET ?;",
      [value, offset]
    )
    rows_to_array(rows)
  end

  def group(*args)
    group_by_ids(nil, args)
  end

  def group_by_ids(ids, args)
    args.join(', ')

    where_clause = ids.nil? ? "" : "WHERE id IN (#{ids.join(",")})"

    rows = connection.execute(
      "SELECT * FROM #{table} #{where_clause} GROUP BY ?;",
      conditions.to_s
    )

    rows_to_array(rows)
  end

  private

  def init_object_from_row(row)
    if row
      data = Hash[columns.zip(row)]
      new(data)
    end
  end

  def rows_to_array(rows)
    collection = BlocRecord::Collection.new
    rows.each { |row| collection << new(Hash[columns.zip(row)]) }
    collection
  end
end
