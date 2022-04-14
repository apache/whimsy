_html do
  if ENV["RACK_BASE_URI"].to_s + '/' == _.env['REQUEST_URI']
    # not sure why Passenger/rack is eating the trailing slash here.
    # add it back in.
    _base href: _.env['REQUEST_URI']
  end

  _title 'ASF Secretary Mail'
  _link rel: 'stylesheet', type: 'text/css', href: "secmail.css?#{@cssmtime}"

  _header_ do
    _h1.bg_success do
      _a 'ASF Secretary Mail', href: '.'
    end
  end

  _div_.index!

  _script src: "./app.js?#{@appmtime}"
  _.render '#index', timeout: 1 do
    _Index mbox: @mbox, messages: @messages
  end
end
