require 'daff'

class SqlSpecHelper
  # The diff describes how to make `actual` to `expected`
  # TODO some outputs can produce unhelpful diffs
  class DaffWrapper
    def initialize(actual, expected, index: false)
      @actual = to_daff_data(actual)
      @expected = to_daff_data(expected)
      @index = index

      @summary = nil
      @alignment = nil
      @diff_view = get_diff_view
      @height = @diff_view.get_height
      @width = @diff_view.get_width
      @view = @diff_view.get_cell_view
    end

    def as_csv
      Daff::TerminalDiffRender.new.render(@diff_view).gsub(/\e\[(\d+)(;\d+)*m/, '')
    end

    def serializable
      @index ? serializable_daff_with_index : {}
    end

    private

    # transform to the format daff understands
    def to_daff_data(hs)
      return [] if hs.nil? || hs.empty?
      # first row contains the keys
      [hs[0].keys] + hs.map(&:values)
    end

    # TODO include the diff summary in serializable
    def summary_hash
      # :row_inserts, :row_updates, :row_deletes, :row_reorders
      # :col_inserts, :col_updates, :col_deletes, :col_reorders, :col_renames
      # :row_count_initial_with_header, :row_count_final_with_header
      # :row_count_initial, :row_count_final
      # :col_count_initial, :col_count_final
      # :different
      {
        different: @summary.different,
      }
    end

    def get_diff_view
      @alignment = Daff::Coopy.compare_tables(Daff::TableView.new(@actual), Daff::TableView.new(@expected)).align
      data_diff = []
      diff_view = Daff::TableView.new(data_diff)
      flags = Daff::CompareFlags.new
      flags.ordered = true
      flags.ignore_whitespace = false
      flags.ignore_case = false
      if @index
        flags.always_show_order = true
        flags.never_show_order = false
        flags.count_like_a_spreadsheet = false
      end
      td = Daff::TableDiff.new(@alignment, flags)
      td.hilite(diff_view)
      @summary = td.get_summary
      diff_view
    end

    # returns CellInfo
    def get_cell(x, y)
      Daff::DiffRender.render_cell(@diff_view, @view, x, y)
    end

    def serializable_daff_with_index
      height = @height
      width = @width
      has_spec = get_cell(1, 1).value == '!'
      header = [{t: '', v: '@@'}]
      if has_spec
        (2...width).each {|c|
          # index, spec, header values
          i = get_cell(c, 0).value.split(':')
          s = get_cell(c, 1).value
          h = get_cell(c, 2).value
          case s
          when ':'
            header << {t: 'move', v: h, m: i}
          when '...'
            header << {t: 'skip', v: h}
          when '+++' # insert missing
            header << {t: 'add', v: h}
          when '---' # remove excess
            header << {t: 'remove', v: h}
          when /\(([^)]+)\)/ # renamed
            if s[0] == ':' # also moved
              header << {t: 'rename', v: h, a: $1, m: i}
            else
              header << {t: 'rename', v: h, a: $1}
            end
          else
            header << {t: '', v: h}
          end
        }
      else
        # no schema difference
        (2...width).each {|c|
          header << {t: '', v: get_cell(c, 1).value}
        }
      end

      rows = []
      ((has_spec ? 3 : 2)...height).each {|r|
        a = get_cell(1, r)
        vs = [{t: action_type(a.value), v: a.value}]
        (2...width).each {|c|
          info = get_cell(c, r)
          cat = info.category
          # move is row-wise
          cat = '' if cat == 'move'
          # `category` specifies "the type of activity going on in the cell".
          # Can be used for visualization.
          if info.updated
            # if info.updated is true, there's lvalue and rvalue (wrong value).
            vs << {
              t: cat,
              # actual
              a: info.lvalue.to_s,
              # expected
              e: info.rvalue.to_s,
            }
          else
            vs << {
              t: cat,
              v: info.value.to_s
            }
          end
        }

        row_t = a.category
        # avoid 'modify' for row type since it actually applies at cell level
        row_t = '' if row_t == 'modify'
        if row_t == 'move'
          # add mapping info for moved rows
          m = (get_cell(0, r).value || '').split(':')
          rows << {t: row_t, v: vs, m: to_zero_based(m)}
        else
          rows << {t: row_t, v: vs}
        end
      }

      {
        header: header,
        rows: rows,
      }
    end

    def to_zero_based(m)
      m.map {|v| (v.to_i - 1).to_s}
    end

    def action_type(tag)
      case tag
      when '+++'
        # add row
        'add'
      when '---'
        'remove'
      when '...'
        'skip'
      when /-+>/
        'modify'
      when '+'
        # add cell
        'add'
      when ':'
        'move'
      else
        ''
      end
    end
  end

  # Spec: https://web.archive.org/web/20160402182940/http://dataprotocols.org/tabular-diff-format/
  # Action Column Tags
  # | `@@`  | The header row, giving column names.
  # | `!`   | The schema row, given column differences.
  # | `+++` |  An inserted row (present in `REMOTE`, not present in `LOCAL`).
  # | `---` | A deleted row (present in `LOCAL`, not present in `REMOTE`).
  # | `->`  | A row with at least one cell modified cell. `-->`, `--->`, `---->` etc. have the same meaning.
  # | Blank | A blank string or `NULL` marks a row common to `LOCAL` and `REMOTE`, given for context.
  # | `...` | Declares that rows common to `LOCAL` and `REMOTE` are being skipped.
  # | `+`   | A row with at least one added cell.
  # | `:`   | A reordered row.

  # Schema Row Tags
  # | `+++`      | An inserted column (present in `REMOTE`, not present in `LOCAL`).
  # | `---`      | A deleted column (present in `LOCAL`, not present in `REMOTE`).
  # | `(<NAME>)` | A renamed column (the name in `LOCAL` is given in parenthesis,
  # |            | and the name in `REMOTE` will be in the header row).
  # | Blank      | A blank string or `NULL` marks a column common to `LOCAL` and `REMOTE`, given for context.
  # | `...`      | Declares that columns common to `LOCAL` and `REMOTE` are being skipped.
  # | `:`        | A reordered column.
end
