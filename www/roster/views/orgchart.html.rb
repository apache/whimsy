#
# Organization Chart
#

_html do
  _title 'ASF Orgchart'
  _base href: '..'
  _link rel: 'stylesheet', href: 'stylesheets/app.css'

  _banner breadcrumbs: {
    roster: '.'
  }

  _h1_ 'ASF Organization Chart'

  _table.table do
    _thead do
      _th 'Title'
      _th 'Contact, Chair, or Person holding that title'
    end

    _tbody do
      @org.sort_by {|key, value| value['info']['role']}.each do |key, value|
        _tr_ do
          # title
          _td do
            _a value['info']['role'], href: "orgchart/#{key}"
          end

          # person holding the role
          _td do
            id = value['info']['id'] || value['info']['chair']
            _a ASF::Person.find(id).public_name, href: "committer/#{id}"
          end
        end
      end
    end
  end
end
