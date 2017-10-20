require_relative 'db_connection'
require 'active_support/inflector'
# NB: the attr_accessor we wrote in phase 0 is NOT used in the rest
# of this project. It was only a warm up.

class SQLObject
  def self.columns
    return @columns if @columns

    @columns = DBConnection.execute2(<<-SQL)
      SELECT
        *
      FROM
        #{table_name}
    SQL

    @columns = @columns.first.map(&:to_sym)
  end

  def self.finalize!
    columns.each do |column|
      define_method(column) { attributes[column] }
      define_method("#{column}=") { |value| attributes[column] = value }
    end
  end

  def self.table_name=(table_name)
    @table_name = table_name
  end

  def self.table_name
    @table_name || to_s.underscore.pluralize
  end

  def self.all
    rows = DBConnection.execute(<<-SQL)
      SELECT
        *
      FROM
        #{table_name}
    SQL

    parse_all(rows)
  end

  def self.parse_all(results)
    results.map do |options|
      self.new(options)
    end
  end

  def self.find(id)
    row = DBConnection.execute(<<-SQL)
      SELECT
        *
      FROM
        #{table_name}
      WHERE
        id = #{id}
    SQL

    parse_all(row).first
  end

  def initialize(params = {})
    params.each do |name, value|
      raise "unknown attribute '#{name}'" unless self.class.columns.include?(name.to_sym)
      send("#{name}=", value)
    end
  end

  def attributes
    @attributes ||= {}
  end

  def attribute_values
    attributes.values
  end

  def insert
    col_names = attributes.keys.join(", ")
    question_marks = (["?"] * attributes.keys.size).join(", ")

    DBConnection.execute(<<-SQL, attribute_values)
      INSERT INTO
        #{self.class.table_name} (#{col_names})
      VALUES
        (#{question_marks})
    SQL

    self.id = DBConnection.last_insert_row_id
  end

  def update
    col_set = attributes.keys.map { |col| "#{col} = ?"}.join(", ")

    DBConnection.execute(<<-SQL, attribute_values, id)
      UPDATE
        #{self.class.table_name}
      SET
        #{col_set}
      WHERE
        id = ?
    SQL
  end

  def save
    id ? update : insert
  end
end
