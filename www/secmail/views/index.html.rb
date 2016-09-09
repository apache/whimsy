_html do
  _title 'ASF Secretary Mail'
  _link rel: 'stylesheet', type: 'text/css', href: "secmail.css?#{@cssmtime}"

  _header_ do
    _h1.bg_success do
      _a 'ASF Secretary Mail', href: '.'
    end
  end

  _div_.index!

  _script src: 'app.js'
  _.render '#index' do
    _Index mbox: @mbox
  end
end
