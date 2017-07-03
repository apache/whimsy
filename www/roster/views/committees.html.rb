#
# List of committees
#

_html do
  _base href: '..'
  _link rel: 'stylesheet', href: 'stylesheets/app.css'
  _whimsy_body(
    title: 'ASF Committees Listing',
    breadcrumbs: {
      roster: '.',
      committee: 'committee/'
    }
  ) do
    _whimsy_panel_table(
      title: 'Summary List of Apache PMCs',
      helpblock: -> {
        _ 'A full list of Apache PMCs; click on the name for a detail page about that PMC.  Non-PMC groups of various kinds '
        _a href: '/roster/group/' do
          _span.glyphicon.glyphicon_lock :aria_hidden, class: 'text-primary', aria_label: 'ASF Members Private'
          _ 'are listed privately.'
        end
      }
    ) do
      _table.table.table_hover do
        _thead do
          _tr do
            _th 'Name'
            _th 'Chair(s)'
            _th 'Description'
          end
        end

        @committees.sort_by {|pmc| pmc.display_name.downcase}.each do |pmc|
          _tr_ do
            _td do
              _a pmc.display_name, href: "committee/#{pmc.name}"
            end

            _td do
              pmc.chairs.each_with_index do |chair, index|
                _span ', ' unless index == 0

                if @members.include? chair[:id]
                  _b! {_a chair[:name], href: "committer/#{chair[:id]}"}
                else
                  _a chair[:name], href: "committer/#{chair[:id]}"
                end
              end
            end

            if not pmc.established
              _td.issue 'Not in committee-info.txt'
            else
              _td pmc.description
            end
          end
        end
      end
    end
  end
end
