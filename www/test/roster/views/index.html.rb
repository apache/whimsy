#
# Landing page
#

_html do
  _title 'ASF Roster'
  _link rel: 'stylesheet', href: '../stylesheets/app.css'

  _a href: 'http://whimsy.apache.org/' do
    _img src: 'https://id.apache.org/img/asf_logo_wide.png',
      alt: 'ASF Logo', title: 'ASF Logo'
  end

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
  end
end
