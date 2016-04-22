#
# Main "layout" for the application, houses a single view
#

_html do
  _base href: @base
  _title 'ASF Board Agenda'
  _link rel: 'stylesheet', href: "../stylesheets/app.css?#{@cssmtime}"

  _div_.main!

  _script src: '../app.js'
  _.render '#main' do
    _Main server: @server, page: @page
  end
end
