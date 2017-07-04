#
# List of all other groups
#

_html do
  _base href: '..'
  _title 
  _link rel: 'stylesheet', href: 'stylesheets/app.css'

  _banner breadcrumbs: {
    roster: '.',
    group: 'group'
  }
  _body? do
    _whimsy_body(
      title: 'ASF Non-PMC Group list',
      breadcrumbs: {
        roster: '.',
        group: 'group'
      }
    ) do
      # ********************************************************************
      # *                             Summary                              *
      # ********************************************************************
      _whimsy_panel_table(
        title: 'Summary - Count of non-PMC Groups',
        helpblock: -> {
          _ 'This data is for non-PMC groups, including unix groups and other LDAP groups; many of which are '
          _span.glyphicon.glyphicon_lock :aria_hidden, class: 'text-primary', aria_label: 'ASF Members Private'
          _ ' private to the ASF.'
        }
      ) do
        _table.counts do
          @groups.group_by(&:last).sort.each do |name, list|
            _tr do
              _td list.count
              _td name
            end
          end
        end
      end

      # ********************************************************************
      # *                          Complete list                           *
      # ********************************************************************
      _whimsy_panel_table(
        title: 'List of non-PMC Groups',
        helpblock: -> {
          _ 'Click on column headers to sort; click on name for '
          _span.glyphicon.glyphicon_lock :aria_hidden, class: 'text-primary', aria_label: 'ASF Members Private'
          _' detail page.'
        }
      ) do
        _table.table.table_hover do
          _thead do
            _tr do
              _th.sorting_asc 'Name', data_sort: 'string-ins'
              _th 'Group type', data_sort: 'string'
              _th 'Notes', data_sort: 'notes'
            end
          end

          _tbody do
            @groups.each do |name, type|
              next if name == 'apldap'
              _tr_ do
                _td {_a name, href: "group/#{name}"}
                _td type

                if @podlings[name]
                  if @podlings[name].status == 'retired'
                    _td.issue "retired podling"
                  else
                    _td "#{@podlings[name].status} podling"
                  end
                else
                  _td
                end
              end
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
