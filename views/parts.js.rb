class Parts < React
  def render
    _ul @@attachments do |attachment|
      _li do
        _a attachment.name, href: attachment.name, target: 'content'
      end
    end
  end
end
