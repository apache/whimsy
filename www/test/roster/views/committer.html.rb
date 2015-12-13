#
# A single committer
#

_html do
  _base href: '..'
  _title @committer[:name][:public_name]
  _link rel: 'stylesheet', href: '../stylesheets/app.css'

  _banner breadcrumbs: {
    roster: 'https://whimsy.apache.org/roster',
    committer: 'https://whimsy.apache.org/roster/committers',
    @committer[:id] => 
      "https://whimsy.apache.org/roster/committers/#{@committer[:id]}"

  }

  _div_.main!

  _script src: '../app.js'
  _.render '#main' do
    _Committer committer: @committer
  end
end
