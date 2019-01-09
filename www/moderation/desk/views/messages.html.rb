# Listing of messages

_html do
  if ENV["RACK_BASE_URI"].to_s + '/' == _.env['REQUEST_URI']
    # not sure why Passenger/rack is eating the trailing slash here.
    # add it back in.
    _base href: _.env['REQUEST_URI']
  end

  _title 'ASF Moderation Helper'
  _link rel: 'stylesheet', type: 'text/css', href: "secmail.css?#{@cssmtime}"

  _header_ do
    _h1.bg_success do
      _a 'ASF Moderation Helper', href: '.', target: '_top'
    end
  end
#  _ __FILE__

  _div_.messages! # must agree with below (and CSS)

  _script src: "./app.js?#{@appmtime}"
  _.render '#messages' do # must agree with above
    _Messages mbox: @mbox, messages: @messages
  end

end
