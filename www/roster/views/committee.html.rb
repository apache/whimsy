#
# A single committee
#

_html do
  _base href: '..'
  _title @committee[:display_name]
  _link rel: 'stylesheet', href: 'stylesheets/app.css'

  _banner breadcrumbs: {
    roster: '.',
    committee: 'committee/',
    @committee[:id] => "/committere/#{@committee[:id]}"
  }

  _div_.main!

  _script src: 'app.js'
  _.render '#main' do
    _Committee committee: @committee, auth: @auth
  end
end
