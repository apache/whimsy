_html do
  _link rel: 'stylesheet', type: 'text/css', href: "secmail.css?#{@cssmtime}"

  _div.index!

  _script src: 'app.js'
  _.render '#index' do
    _Index mbox: @mbox
  end
end
