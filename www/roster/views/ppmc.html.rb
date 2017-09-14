#
# A single Podling PMC
#

_html do
  _base href: '..'
  _link rel: 'stylesheet', href: "stylesheets/app.css?#{cssmtime}"
  _title  @ppmc[:display_name]

  _body? do
    _whimsy_body(
      breadcrumbs: {
        roster: '.',
        ppmc: 'ppmc/',
        @ppmc[:id] => "ppmc/#{@ppmc[:id]}"
      }
    ) do
      _div_.main!
      _script src: 'app.js'
      _.render '#main' do
        _PPMC ppmc: @ppmc, auth: @auth
      end
    end
  end
end
