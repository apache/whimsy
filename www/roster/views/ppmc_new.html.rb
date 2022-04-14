#
# Create a new podling (PPMC)
#

_html do
  _base href: '..'
  _link rel: 'stylesheet', href: "stylesheets/app.css?#{cssmtime}"
  _title 'Create a Podling'

  _body? do
    _whimsy_body(
      breadcrumbs: {
        roster: '.',
        ppmc: 'ppmc/',
        _new_: "ppmc/_new_"
      }
    ) do
      _div_.main!
    end

    _script src: "app.js?#{appmtime}"
    _.render '#main', timeout: 1 do
      _PPMCNew auth: @auth, pmcsAndBoard: @pmcsAndBoard,
        officersAndMemers: @officersAndMembers, ipmc: @ipmc
    end
  end
end
