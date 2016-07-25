#
# Content-less stub HTML which will fetch and display agenda
#
_html do
  _base href: @base
  _title 'ASF Board Agenda'
  _link rel: 'stylesheet', href: "../stylesheets/app.css?#{@cssmtime}"
  _meta name: 'viewport', content: 'width=device-width, initial-scale=1.0'

  _div.main! do
    _header
    _footer
  end

  _script src: '../app.js', lang: 'text/javascript'
  _script %{
    React.render(React.createElement(Main, 
      #{JSON.generate(server: @server, page: @page)}),
      document.getElementById("main"))
  }
end
