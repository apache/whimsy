#
# A single Podling PMC
#

_html do
  _base href: '..'
  _title @ppmc[:display_name]
  _link rel: 'stylesheet', href: 'stylesheets/app.css'

  _banner breadcrumbs: {
    roster: '.',
    ppmc: 'ppmc/',
    @ppmc[:id] => "ppmc/#{@ppmc[:id]}"
  }

  _div_.main!

  _script src: 'app.js'
  _.render '#main' do
    _PPMC ppmc: @ppmc, auth: @auth
  end
end
