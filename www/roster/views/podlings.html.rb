#
# List of all Podings
#

_html do
  _title 'ASF Podling list'
  _link rel: 'stylesheet', href: 'stylesheets/app.css'
  _style %{
    p {margin-top: 0.5em}
  }

  _banner breadcrumbs: {
    roster: '.',
    podlings: 'podlings'
  }

  # ********************************************************************
  # *                             Summary                              *
  # ********************************************************************

  _h1_ 'Summary'
 
  _table.counts do
    @podlings.group_by {|podling| podling[:status]}.sort.each do |status, list|
      _tr do
        _td list.count
        _td do
          _a status, href: "http://incubator.apache.org/projects/##{status}"
        end
      end
    end
  end

  _p do
    _ 'Data is derived from:'
    _a 'podlings.xml', href: 'https://svn.apache.org/repos/asf/incubator/public/trunk/content/podlings.xml'
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

  _h1_ 'Podlings'
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
      @podlings.sort_by {|podling| podling[:name].downcase}.each do |podling|
        status = (@attic.include?(podling[:id]) ? 'attic' : podling[:status])

        _tr_ class: color[status] do
          _td do
            _a podling[:name], href:
              "http://incubator.apache.org/projects/#{podling[:id]}.html"
          end

          if @committees.include? podling[:id]
            _td data_sort_value: "#{podling[:status]} - pmc" do
              _a podling[:status], href: "committee/#{podling[:id]}"
            end
          elsif @attic.include? podling[:id]
            _td data_sort_value: "#{podling[:status]} - attic" do
              _a podling[:status], href:
                "http://attic.apache.org/projects/#{podling[:id]}.html"
            end
          else
            _td podling[:status]
          end

          _td podling[:description]
        end
      end
    end
  end

  _script %{
    $(".table").stupidtable();
  }
end
