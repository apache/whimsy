#
# A single group
#

_html do
  _base href: '..'
  _link rel: 'stylesheet', href: "stylesheets/app.css?#{cssmtime}"
  _body? do
    _whimsy_body(
      title: @group[:id],
      breadcrumbs: {
        roster: '.',
        group: 'group/',
        @group[:id] => "group/#{@group[:id]}"
      }
    ) do
      _div_.main!
    end

    _script src: 'app.js'
    _.render '#main' do
      _Group group: @group, auth: @auth
    end
  end
end
