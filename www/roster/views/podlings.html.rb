#
# List of all Podings
#

_html do
  _title 'ASF Podling list'
  _link rel: 'stylesheet', href: 'stylesheets/app.css'

  _banner breadcrumbs: {
    roster: '.',
    podlings: 'podlings'
  }

  members = ASF::Member.list.dup

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

  # ********************************************************************
  # *                          Complete list                           *
  # ********************************************************************

  color = {
    'current'   => 'bg-info',
    'graduated' => 'bg-success',
    'retired'   => 'bg-warning'
   }

  _h1_ 'Podlings'

  _table.table.table_hover do
    _thead do
      _tr do
        _th.sorting_asc 'name', data_sort: 'string-ins'
        _th 'description', data_sort: 'string'
        _th 'status', data_sort: 'string'
      end
    end

    _tbody do
      @podlings.sort_by {|podling| podling[:name].downcase}.each do |podling|
        _tr_ class: color[podling[:status]] do
          _td do
            _a podling[:name], href:
              "http://incubator.apache.org/projects/#{podling[:id]}.html"
          end

          _td podling[:description]
          _td podling[:status]
        end
      end
    end
  end


  _script %{
    $(".table").stupidtable();
  }
end
