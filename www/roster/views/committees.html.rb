#
# List of committees
#

_html do
  _base href: '..'
  _link rel: 'stylesheet', href: "stylesheets/app.css?#{cssmtime}"
  _whimsy_body(
    title: 'ASF PMC Listing',
    breadcrumbs: {
      roster: '.',
      committee: 'committee/'
    }
  ) do
    _p do
      _ 'A full list of Apache PMCs; click on the name for a detail page about that PMC.  Non-PMC groups of various kinds '
      _a href: '/roster/group/' do
        _span.glyphicon.glyphicon_lock :aria_hidden, class: 'text-primary', aria_label: 'ASF Members Private'
        _ 'are listed privately.'
      end
    end
    _p do
      _ 'Click on column names to sort.'
      _{"&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;"}
      "ABCDEFGHIJKLMNOPQRSTUVWXYZ".each_char do |c|
        _a c, href: "committee/##{c}"
      end
    end

    _table.table.table_hover do
      _thead do
        _tr do
          _th.sorting_asc 'Name', data_sort: 'string-ins'
          _th 'Chair(s)', data_sort: 'string'
          _th 'Description', data_sort: 'string'
        end
      end

      prev_letter=nil
      @committees.sort_by {|pmc| pmc.display_name.downcase}.each do |pmc|
        letter = pmc.display_name.upcase[0]
        _tr_ do
          _td do
            if letter != prev_letter
              _a pmc.display_name, href: "committee/#{pmc.name}", id: letter
            else
              _a pmc.display_name, href: "committee/#{pmc.name}"
            end
            prev_letter = letter
          end

          _td do
            pmc.chairs.each_with_index do |chair, index|
              _span ', ' unless index == 0

              if @members.include? chair[:id]
                _b! {_a chair[:name], href: "committer/#{chair[:id]}"}
              else
                _a chair[:name], href: "committer/#{chair[:id]}"
              end
            end
          end

          if not pmc.established
            _td.issue 'Not in committee-info.txt'
          else
            _td pmc.description
          end
        end
      end
    end
  end
  _script %{
    $(".table").stupidtable();
  }
end
