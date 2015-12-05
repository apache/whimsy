_html do
  _ul do
    _li 'text'
    _li 'headers'

    @message[:attachments].each do |attachment|
      _li attachment[:name]
    end
  end
end
