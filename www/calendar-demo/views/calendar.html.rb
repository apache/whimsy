require 'date'

_html do
  _base href: '..'
  _link rel: 'stylesheet', href: 'css/calendar.css'

  _div_ id: 'page'

  _script src: 'js/react-0.12.2.min.js'
  _script src: 'calendar.js'

  _.render '#page' do
    _Calendar year: @year, month: @month-1, items: @items
  end
end
