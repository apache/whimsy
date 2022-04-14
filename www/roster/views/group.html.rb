#
# A single group
#

_html do
  _base href: '..'
  _link rel: 'stylesheet', href: "stylesheets/app.css?#{cssmtime}"
  _title @group[:id]

  _body? do
    _whimsy_body(
      breadcrumbs: {
        roster: '.',
        group: 'group/',
        @group[:id] => "group/#{@group[:id]}"
      }
    ) do
      _div_.main!
    end

    _script src: "app.js?#{appmtime}"
    _.render '#main', timeout: 1 do
      _Group group: @group, auth: @auth
    end
  end
end
