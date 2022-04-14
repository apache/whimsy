#
# A single committee
#

_html do
  _base href: '..'
  _title @nonpmc[:display_name]
  _link rel: 'stylesheet', href: "stylesheets/app.css?#{cssmtime}"

  _body? do
    _whimsy_body(
      breadcrumbs: {
        roster: '.',
        nonpmc: 'nonpmc/',
        @nonpmc[:id] => "nonpmc/#{@nonpmc[:id]}"
      }
    ) do
      _div_.main!
    end

    _script src: "app.js?#{appmtime}"
    _.render '#main', timeout: 1 do
      _NonPMC nonpmc: @nonpmc, auth: @auth
    end
  end
end
