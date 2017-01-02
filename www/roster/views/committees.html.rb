#
# List of committees
#

_html do
  _base href: '..'
  _title 'ASF Committee Roster'
  _link rel: 'stylesheet', href: 'stylesheets/app.css'

  _banner breadcrumbs: {
    roster: '.',
    committee: 'committee/'
  }

  _h1 'PMCs'

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
            if @members.include? chair[:id]
              _b! {_a chair[:name], href: "committer/#{chair[:id]}"}
            else
              _a chair[:name], href: "committer/#{chair[:id]}"
            end

            _span ', ' unless index == 0
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
