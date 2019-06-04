#
# Debugging tool shell
#
_html do
  _base href: '..'
  _link rel: 'stylesheet', href: "stylesheets/app.css?#{cssmtime}"
  _body? do
    _whimsy_body(
      title: "Whimsy Roster Debugger",
      breadcrumbs: {
        roster: '.',
        test: '/test.cgi'
      }
    ) do
      _h3 "Before debugger"
      _div_.main!
      _h3 "After debugger!"
    end

    _script src: "app.js?#{appmtime}"
    _.render '#main' do
      _Debugger committer: @committer, auth: @auth
    end
  end
end
