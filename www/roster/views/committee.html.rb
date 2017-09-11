#
# A single committee
#

_html do
  _base href: '..'
  _link rel: 'stylesheet', href: "stylesheets/app.css?#{cssmtime}"
  _body? do
    _whimsy_body(
      title: @committee[:display_name],
      breadcrumbs: {
        roster: '.',
        committee: 'committee/',
        @committee[:id] => "committee/#{@committee[:id]}"
      }
    ) do
      _div_.main!
    end

    _script src: 'app.js'
    _.render '#main' do
      _PMC committee: @committee, auth: @auth
    end
  end
end
