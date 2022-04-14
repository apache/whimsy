#
# A single committer
#

_html do
  _base href: '..'
  _link rel: 'stylesheet', href: "stylesheets/app.css?#{cssmtime}"
  _body? do
    _whimsy_body(
      title: @committer[:name][:public_name],
      breadcrumbs: {
        roster: '.',
        committer: 'committer/',
        @committer[:id] => "committer/#{@committer[:id]}"
      }
    ) do
      _div_.main!
    end

    _script src: "app.js?#{appmtime}"
    _.render '#main', timeout: 1 do
      _Person committer: @committer, auth: @auth
    end
  end
end
