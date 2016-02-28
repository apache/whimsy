#
# A single committer
#

_html do
  _base href: '..'
  _title @committer[:name][:public_name]
  _link rel: 'stylesheet', href: 'stylesheets/app.css'

  _banner breadcrumbs: {
    roster: '.',
    committer: 'committer/',
    @committer[:id] => "committer/#{@committer[:id]}"
  }

  _div_.main!

  _script src: 'app.js'
  _.render '#main' do
    _Committer committer: @committer, auth: @auth
  end
end
