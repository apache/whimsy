#
# A single committee
#

_html do
  _base href: '..'
  _title @committee[:display_name]
  _link rel: 'stylesheet', href: "stylesheets/app.css?#{cssmtime}"

  _body? do
    _whimsy_body(
      breadcrumbs: {
        roster: '.',
        committee: 'committee/',
        @committee[:id] => "committee/#{@committee[:id]}"
      }
    ) do
      _div_.main!
    end

    _script src: "app.js?#{appmtime}"
    _.render '#main', timeout: 1 do
      _PMC committee: @committee, auth: @auth
    end
  end
end
