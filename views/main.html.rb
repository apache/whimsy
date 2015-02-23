#
# Main "layout" for the application, houses a single view
#

Wunderbar::CALLERS_TO_IGNORE.clear

_html do
  _base href: @base
  _title 'ASF Board Agenda'
  _link rel: 'stylesheet', href: '../stylesheets/app.css'

  _div.main!

  _script src: '../app.js'
  _.render '#main' do
    _Main parsed: @parsed, agenda: @agenda, agendas: @agendas
  end
end
