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

  # polyfills
  _script src: 'javascript/es6-promise.js'
  _script src: 'javascript/fetch.js'

  _script src: 'app.js'
  _.render '#main' do
    _CommitterSearch
  end
end
