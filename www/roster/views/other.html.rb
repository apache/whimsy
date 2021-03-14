#
# List of apparently unused project groups
#

_html do
  _base href: '..'
  _link rel: 'stylesheet', href: "stylesheets/app.css?#{cssmtime}"
  _whimsy_body(
    title: 'LDAP projects without apparent active use',
    breadcrumbs: {
      roster: '.',
      other: 'other/'
    }
  ) do
    _p do
      _ 'List of LDAP ou=project groups with no apparent active use.'
      _ 'The list of LDAP projects is compared with:'
      _ul do
        _li 'Current PMCs'
        _li 'ASF committees (non-PMCs)'
        _li 'Current podlings'
        _li 'Petri cultures'
      end
      _ 'Any that remain are then checked against:'
      _ul do
        _li 'Attic projects'
        _li 'Retired podlings'
        _li 'Podling aliases'
        _li 'Podling graduated as part of another TLP'
      end
      _p 'None of the above normally have an LDAP project group'
    end

    _p 'Click on column names to sort.'

    _table.table.table_hover do
      _thead do
        _tr do
          _th.sorting_asc 'Name', data_sort: 'string-ins'
          _th 'Description', data_sort: 'string'
          _th 'End Date', data_sort: 'string'
        end
      end
      _tbody do
        @others.sort.each do |k,v|
          _tr do
            _td k
            _td v[:type]
            _td v[:date]
          end
        end
      end
    end
  end
  _script %{
    $(".table").stupidtable();
  }
end
