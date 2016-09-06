_html do
  _link rel: 'stylesheet', type: 'text/css', href: "secmail.css?#{@cssmtime}"

  _header_ do
    _h1.bg_success do
      _a 'Secretary Mail', href: '../..', target: '_parent'
    end
  end

  _div.index!

  _script src: 'app.js'
  _.render '#index' do
    _Index mbox: @mbox
  end
end
