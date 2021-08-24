require 'rspec/expectations'

class SqlSpecHelper
  class SqlCompare
    attr_reader :actual, :expected

    def initialize(helper, expected, cmds: nil, limit: 100, collapsed: false, show_daff_table: true, daff_csv_show_index: false)
      @results = helper.run_sql(cmds: cmds, label: 'Results: Actual', limit: limit, collapsed: collapsed)
      @actual = @results.is_a?(Array) ? @results.last.to_a : @results.to_a
      @limit = limit
      Display.status("Running expected query...")
      @expected = expected.to_a
      @daff_csv_show_index = daff_csv_show_index

      Display.log('Query returned no rows', 'Results: Actual') if @actual.size == 0
      Display.table(@expected, label: 'Results: Expected', tab: true, allow_preview: true)
      if show_daff_table && @actual.size > 0 && @expected != @actual
        # set `index: true` to collect ordering data (row/column mapping)
        daff_data = DaffWrapper.new(@actual, @expected, index: true).serializable
        Display.daff_table(daff_data, label: 'Diff', tab: true, allow_preview: true)
      end

      @column_blocks ||= {}
      @rows_blocks = []
    end

    def column(name, &block)
      @column_blocks[name.to_sym] = block.to_proc
      self
    end

    def rows(&block)
      @rows_blocks << block.to_proc
      self
    end

    def spec(&block)
      return if @spec_called
      @spec_called = true

      _self = self
      column_blocks = @column_blocks
      rows_blocks = @rows_blocks
      it_blocks = @it_blocks
      daff_csv_show_index = @daff_csv_show_index

      RSpec.describe "Query" do
        let(:actual) { _self.actual }
        let(:expected) { _self.expected }

        describe "columns" do
          expected.first.each do |key, value|
            describe "column \"#{key}\"" do
              it "should be included within results" do
                if (actual_row = actual&.first)
                  expect(actual_row).to have_key(key), "missing column \"#{key}\""
                else
                  RSpec::Expectations.fail_with("the query returned no row")
                end
              end

              if value
                # TODO `value.class` is type in Ruby, and can be misleading
                it "should be a #{value.class.name} value" do
                  if (actual_row = actual&.first)
                    if (actual_value = actual_row[key])
                      expect(actual_value).to be_a(value.class), "column \"#{key}\" should be #{value.class}, not #{actual_value.class}"
                    else
                      RSpec::Expectations.fail_with("missing column \"#{key}\"")
                    end
                  else
                    RSpec::Expectations.fail_with("the query returned no row")
                  end
                end
              end

              self.instance_eval(&column_blocks[key]) if column_blocks[key]
            end
          end
        end

        describe "rows" do
          matcher :eq_table do |expected|
            match {|actual| actual == expected}
            failure_message do |actual|
              ("rows did not match expected\n" + DaffWrapper.new(actual, expected, index: daff_csv_show_index).as_csv).gsub(/\r?\n/, '<:LF:>')
            end
          end

          it "should have #{expected.count} rows" do
            if (count = actual&.count)
              expect(count).to eq(expected.count), "expected #{expected.count} rows, got #{count} rows"
            else
              RSpec::Expectations.fail_with("the query returned no row")
            end
          end

          rows_blocks.each do |block|
            self.instance_eval(&block)
          end

          it "should match the expected" do
            if actual.empty?
              RSpec::Expectations.fail_with("the query returned no row")
            else
              expect(actual).to eq_table expected
            end
          end
        end

        self.instance_eval(&block) if block
      end
    end
  end
end
