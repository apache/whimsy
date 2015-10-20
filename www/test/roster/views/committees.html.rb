#
# List of committees
#

_html do
  _base href: '..'
  _title 'ASF Committee Roster'
  _link rel: 'stylesheet', href: '../stylesheets/app.css'

  _banner breadcrumbs: {
    roster: 'https://whimsy.apache.org/roster',
    committee: 'https://whimsy.apache.org/roster/committere'
  }

  _h1 'PMCs'

  _table do
    @committees.each do |pmc|
      _tr_ do
        _td do
          _a pmc.display_name, href: pmc.name
        end
        _td do
          pmc.chairs.each_with_index do |chair, index|
            if @members.include? chair[:id]
              _b! {_a chair[:name], href: "../committer/#{chair[:id]}"}
            else
              _a chair[:name], href: "../committer/#{chair[:id]}"
            end

            _span ', ' unless index == 0
          end
        end
      end
    end
  end
end
