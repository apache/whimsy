#
# A single group
#

_html do
  _base href: '..'
  _title @group[:id]
  _link rel: 'stylesheet', href: 'stylesheets/app.css'

  _banner breadcrumbs: {
    roster: '.',
    group: 'group/',
    @group[:id] => "group/#{@group[:id]}"
  }

  _div_.main!

  _script src: 'app.js'
  _.render '#main' do
    _Group group: @group, auth: @auth
  end
end
