#
# Content-less stub HTML which will fetch and display agenda
#
_html do
  _base href: @base
  _title 'ASF Board Agenda'
  _link rel: 'stylesheet', href: "../stylesheets/app.css?#{@cssmtime}"
  _meta name: 'viewport', content: 'width=device-width, initial-scale=1.0'

  _div.main!

  _script src: "../app.js?#{@appmtime}", lang: 'text/javascript'
  _script %{
    new Vue({el: "#main", render: function($h) {
      return $h("div", {attrs: {id: "main"}}, [$h(Main, {props:
      #{JSON.generate(server: @server, page: @page)}})])}})
  }
end
