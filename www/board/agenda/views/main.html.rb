#
# Main "layout" for the application, houses a single view
#

_html do
  _base href: @base
  _title 'ASF Board Agenda'
  _link rel: 'stylesheet', href: "../stylesheets/app.css?#{@cssmtime}"
  _link rel: 'manifest', href: "../manifest.json?#{@manmtime}"
  _meta name: 'viewport', content: 'width=device-width, initial-scale=1.0'

  _div_.main!

  _script src: "../app.js?#{@appmtime}", lang: 'text/javascript'

  _.render '#main', timeout: 1 do
    _Main server: @server, page: @page
  end
end
