#
# Main "layout" for the application, houses a single view
#

_html do
  _base href: @base
  _title 'ASF Board Agenda'
  _link rel: 'stylesheet', href: '../stylesheets/app.css'

  _div.main!

  _script src: '../app.js'
  _.render '#main' do
    _Main parsed: @parsed, agenda: @agenda, agendas: @agendas, path: @path,
      query: @query, etag: @etag
  end
end
