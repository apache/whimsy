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
      end
      _ 'Any that remain are then checked against:'
      _ul do
        _li 'Attic projects'
        _li 'Retired podlings'
        _li 'Petri projects (cultures)'
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
        end
      end
      _tbody do
        @otherids.sort.each do |other|
          _tr_ do
            _td do
              _a other
            end

            if @atticids.include? other
              _td 'Attic'
            elsif @petriids.include? other
              _td 'Petri project'
            elsif @retiredids.include? other
              _td 'Retired Podling'
            elsif @podlingAliases.include? other
              _td "Podling alias for #{@podlingAliases[other]}"
            elsif @podlingURLs.include? other
              _td do
                url = @podlingURLs[other]
                _ "Podling graduated as"
                _a url, href: url
              end
            else              
              _td 'Unkown'
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
