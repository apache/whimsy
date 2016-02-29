#
# List of all other groups
#

_html do
  _base href: '..'
  _title 'ASF Group list'
  _link rel: 'stylesheet', href: 'stylesheets/app.css'

  _banner breadcrumbs: {
    roster: '.',
    group: 'group'
  }

  # ********************************************************************
  # *                             Summary                              *
  # ********************************************************************

  _h1_ 'Summary'
 
  _table.counts do
    @groups.group_by(&:last).sort.each do |name, list|
      _tr do
        _td list.count
        _td name
      end
    end
  end

  # ********************************************************************
  # *                          Complete list                           *
  # ********************************************************************

  _h1_ 'Groups'

  _table.table.table_hover do
    _thead do
      _tr do
        _th.sorting_asc 'name', data_sort: 'string-ins'
        _th 'group type', data_sort: 'string'
        _th 'notes', data_sort: 'notes'
      end
    end

    _tbody do
      @groups.each do |name, type|
        next if name == 'apldap'
        _tr_ do
          _td {_a name, href: "group/#{name}"}
          _td type

          if @podlings[name]
            if @podlings[name][:status] == 'retired'
              _td.issue "retired podling"
            else
              _td "#{@podlings[name][:status]} podling"
            end
          else
            _td
          end
        end
      end
    end
  end


  _script %{
    $(".table").stupidtable();
  }
end
