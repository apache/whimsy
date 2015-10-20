#
# Landing page
#

_html do
  _title 'ASF Roster'
  _link rel: 'stylesheet', href: '../stylesheets/app.css'

  _banner breadcrumbs: {
    roster: 'https://www.whimsy.org/roster'
  }

  _h1_ 'Roster'

  _table do

    ### committers

    _tr do
      _td do
        _a @committers.length, href: 'committer/'
      end

      _td do
        _a 'Committers', href: 'committer/'
      end

      _td 'Search for committers by name, user id, or email address'
    end

    ### PMCs

    _tr do
      _td do
        _a @committees.length, href: 'committee/'
      end

      _td do
        _a 'PMCs', href: 'committee/'
      end

      _td 'Active projects at the ASF'
    end

  end
end
