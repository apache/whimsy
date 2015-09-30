#
# A single committer
#

_html do
  _base href: '..'
  _title 'ASF Committer Search'
  _link rel: 'stylesheet', href: '../stylesheets/app.css'

  _a href: 'http://whimsy.apache.org/' do
    _img src: 'https://id.apache.org/img/asf_logo_wide.png',
      alt: 'ASF Logo', title: 'ASF Logo'
  end

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
