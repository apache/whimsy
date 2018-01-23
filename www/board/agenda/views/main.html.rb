#
# Main "layout" for the application, houses a single view
#

_html do
  _base href: @base
  _title 'ASF Board Agenda'
  _link rel: 'stylesheet', href: "../stylesheets/app.css?#{@cssmtime}"
  _meta name: 'viewport', content: 'width=device-width, initial-scale=1.0'

  _div_.main!

  # force es5 for non-test visitors.  Visitors using browsers that support
  # ServiceWorkers will receive es2017 versions of the script via
  # views/bootstrap.html.erb.
  app = (ENV['RACK_ENV'] == 'test' ? 'app' : 'app-es5')
  _script src: "../#{app}.js?#{@appmtime}", lang: 'text/javascript'

  _.render '#main' do
    _Main server: @server, page: @page
  end
end
