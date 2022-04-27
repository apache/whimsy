#
# List of all Podings
#

_html do
  _link rel: 'stylesheet', href: "stylesheets/app.css?#{cssmtime}"
  _style %{
    p {margin-top: 0.5em}
  }
  _body? do
    _whimsy_body(
      title: 'ASF Petri Cultures',
      breadcrumbs: {
        roster: '.',
        petri: 'petri'
      }
    ) do

      _h2 'A listing of cultures from Apache Petri'
      _p do
        _ 'The data is derived from '
        _a 'info.yaml', href: 'https://petri.apache.org/info.yaml'
      end

      _br

      _h5 'Click on a column heading to change the sort order'

      _table.table.table_hover do
        _thead do
          _tr do
            _th.sorting_asc 'Id', data_sort: 'string-ins'
            _th 'Name', data_sort: 'string'
            _th 'Status', data_sort: 'string'
            _th 'Description', data_sort: 'string'
          end
        end
        _tbody do
          @petri.sort_by {|petri| petri.name.downcase}.each do |petri|
            _tr do
              _td do
                _a petri.id, href: "https://petri.apache.org/#{petri.id}"
              end
              _td petri.name
              _td petri.status
              _td petri.description
            end
          end
        end
      end
    end

    _script %{
      $(".table").stupidtable();
    }
  end
end
