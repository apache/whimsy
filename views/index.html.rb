_html do
  _style %{
    td:nth-child(2), th:nth-child(2) {
      padding-right: 7px;
      padding-left: 7px;
    }

   .selected {
     background-color: yellow
   }
  }

  _div.index!

  _script src: 'app.js'
  _.render '#index' do
    _Index mbox: @mbox
  end
end
