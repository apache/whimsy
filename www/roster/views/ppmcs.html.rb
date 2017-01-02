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

    @ppmcs.sort_by {|ppmc| ppmc.display_name.downcase}.each do |ppmc|
      _tr_ do
        _td do
          if @projects.include? ppmc.name
            _a ppmc.display_name, href: "ppmc/#{ppmc.name}"
          else
            _span ppmc.display_name
          end
        end

        _td ppmc.startdate

        _td ppmc.description
      end
    end
  end
end
