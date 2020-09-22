#
# List of all Podings
#

# Match name and aliases to find the entry
def findName(podling, list)
  if list.include?(podling.name)
    return podling.name
  end
  podling.resourceAliases.each do |a|
    if list.include? a
      return a
    end
  end
  return nil
end

_html do
  _link rel: 'stylesheet', href: "stylesheets/app.css?#{cssmtime}"
  _style %{
    p {margin-top: 0.5em}
  }
  _body? do
    _whimsy_body(
      title: 'ASF Podling list',
      breadcrumbs: {
        roster: '.',
        podlings: 'podlings'
      }
    ) do

      # ********************************************************************
      # *                             Summary                              *
      # ********************************************************************
      _whimsy_panel_table(
        title: 'Podling Summary',
        helpblock: -> {
          _ 'Podling data is derived from:'
          _a 'podlings.xml', href: ASF::SVN.svnpath!('incubator-podlings', 'podlings.xml')
        }
      ) do
        _table.counts do
          @podlings.group_by {|podling| podling.status}.sort.each do |status, list|
            _tr do
              _td list.count
              _td do
                _a status, href: "http://incubator.apache.org/projects/##{status}"
              end
            end
          end
        end
      end

      # ********************************************************************
      # *                          Complete list                           *
      # ********************************************************************
      color = {
        'current'   => 'bg-info',
        'graduated' => 'bg-success',
        'retired'   => 'bg-warning',
        'attic'     => 'bg-danger'
       }

      _h2_ 'Podlings'
      _h5_ do
        _ 'Click on a column heading to change the sort order ('
        color.each do |state, clazz|
          _span state, class: clazz
          _ " "
        end
        _ ")"
      end

      _table.table.table_hover do
        _thead do
          _tr do
            _th.sorting_asc 'Name', data_sort: 'string-ins'
            _th 'Status', data_sort: 'string'
            _th 'Description', data_sort: 'string'
          end
        end

        _tbody do
          @podlings.sort_by {|podling| podling.name.downcase}.each do |podling|
            attic = findName(podling, @attic)
            pmc = findName(podling, @committees)
            status = (attic ? 'attic' : podling.status)

            _tr_ class: color[status] do
              _td do
                _a podling.display_name, href:
                  "http://incubator.apache.org/projects/#{podling.name}.html"
              end

              if pmc
                _td data_sort_value: "#{podling.status} - pmc" do
                  _a podling.status, href: "committee/#{pmc}"
                end
              elsif attic
                _td data_sort_value: "#{podling.status} - attic" do
                  _a podling.status, href:
                    "http://attic.apache.org/projects/#{attic}.html"
                end
              else
                _td podling.status
              end

              _td podling.description
            end
          end
        end
      end
    end
  end

  _script %{
    $(".table").stupidtable();
  }
end
