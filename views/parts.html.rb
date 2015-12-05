#
# Display the list of parts for a given message
#

_html do
  _ul_ do
    _li! {_a 'text', href: '_body_', target: 'content'}
    _li! {_a 'headers', href: '_headers_', target: 'content'}
  end

  _ul_ do
    @message[:attachments].each do |attachment|
      _li do
        _a attachment[:name], href: attachment[:name], target: 'content'
      end
    end
  end
end
