#
# A single committer
#

_html do
  _base href: '..'
  _title 'ASF Committer Search'
  _link rel: 'stylesheet', href: '../stylesheets/app.css'

  _banner breadcrumbs: {
    roster: 'https://whimsy.apache.org/roster',
    committer: 'https://whimsy.apache.org/roster/committers'
  }

  _h1 'Committer - Search'

  _div_.main!

  _script src: 'app.js'
  _.render '#main' do
    _CommitterSearch
  end
end
