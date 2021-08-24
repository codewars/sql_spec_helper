# frozen_string_literal: true

require 'sequel'

require_relative 'sql_spec_helper/display'
require_relative 'sql_spec_helper/daff_wrapper'
require_relative 'sql_spec_helper/compare'

class SqlSpecHelper
  attr_reader :sql, :db

  def initialize(solution_path)
    @sql = File.read(solution_path)
    @commands = sql_commands(@sql)
    @db = connect
  end

  # `show_daff_table: true` display diff table
  # `daff_csv_show_index: true` include index in test output
  def compare_with(expected, limit: 100, collapsed: false, show_daff_table: true, daff_csv_show_index: false, &block)
    sql_compare = SqlCompare.new(
      self,
      expected,
      cmds: @commands,
      limit: limit,
      collapsed: collapsed,
      show_daff_table: show_daff_table,
      daff_csv_show_index: daff_csv_show_index
    )
    sql_compare.instance_eval(&block) if block

    sql_compare.spec
    sql_compare.actual
  end

  # The main method used when running user's code.
  # Returns an Array of `Sequel::Adapter::Dataset` unless commands contained only one `SELECT`.
  # Returns `nil` if no `SELECT`.
  def run_sql(cmds: nil, limit: 100, print: true, label: 'SELECT Results', collapsed: false, &block)
    Display.status("Running sql commands...")
    cmds ||= @commands
    results = Array(cmds).each_with_object([]) do |cmd, results|
      dataset = run_cmd(cmd) || []
      result = dataset.to_a
      next if result.empty?

      lbl = label
      lbl += " (Top #{limit} of #{result.size})" if result.size > limit
      lbl = "-" + lbl if collapsed

      block.call(dataset, lbl) if block

      Display.table(result.take(limit), label: lbl, allow_preview: true) if print
      results.push(dataset)
    end

    if results.length > 1
      results
    else
      results.first
    end

  rescue Sequel::DatabaseError => ex
    Display.error(ex.message.strip)
  end

  private

  # Connect the database
  def connect
    Display.status "Connecting to database..."
    case ENV['DATABASE_TYPE']
    when 'sqlite'
      Sequel.sqlite
    when 'postgres'
      Sequel.connect(
        adapter: 'postgres',
        host: ENV['PGHOST'],
        user: ENV['PGUSER'],
        port: ENV['PGPORT'],
        database: ENV['DATABASE_NAME'] || ENV['PGDATABASE'],
      )
    when 'mssql'
      Sequel.connect(
        adapter: 'tinytds',
        host: ENV['MSSQL_HOST'],
        port: ENV['MSSQL_PORT'],
        user: ENV['MSSQL_USER'],
        password: ENV['MSSQL_PASS'],
      )
    else
      raise "Unknown database type #{ENV['DATABASE_TYPE']}"
    end
  end

  def sql_commands(sql)
    split_sql_commands(clean_sql(sql))
  end

  def run_cmd(cmd)
    select_cmd?(cmd) ? @db[cmd] : @db.run(cmd)
  end

  def clean_sql(sql)
    sql.gsub(/(\/\*([\s\S]*?)\*\/|--.*)/, "")
  end

  def select_cmd?(cmd)
    (cmd.strip =~ /^(SELECT|WITH)/i) == 0
  end

  def split_sql_commands(sql)
    # first we want to seperate select statements into chunks
    chunks = sql.split(/;[ \n\r]*$/i).select {|s| !s.empty?}.chunk {|s| select_cmd?(s)}
    # select statements need to stay individual so that we can return individual datasets, but we can group other statements together
    chunks.each_with_object([]) do |(select, cmds), final|
      if select
        final.concat(cmds)
      else
        final.push(cmds.join(";\n"))
      end
    end
  end
end
