#
# List of committees
#

_html do
  _base href: '..'
  _title 'ASF Podling PMC Roster'
  _link rel: 'stylesheet', href: 'stylesheets/app.css'

  _banner breadcrumbs: {
    roster: '.',
    ppmc: 'ppmc/'
  }

  _h1 'Podling Project Management Committees (PPMCs)'

  _table.table.table_hover do
    _thead do
      _tr do
        _th 'Name'
        _th 'Established'
        _th 'Description'
      end
    end

    project_names = @projects.map {|project| project.name}
    @ppmcs.sort_by {|ppmc| ppmc.display_name.downcase}.each do |ppmc|
      _tr_ do
        _td do
          if project_names.include? ppmc.name
            _a ppmc.display_name, href: "ppmc/#{ppmc.name}"
          else
            _a.label_danger ppmc.display_name, href: "ppmc/#{ppmc.name}"
          end
        end

        _td ppmc.startdate

        _td ppmc.description
      end
    end
  end
end
