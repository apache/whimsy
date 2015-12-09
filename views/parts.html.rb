#
# Display the list of parts for a given message
#

_html do
  _ul_ do
    _li! {_a 'text', href: '_body_', target: 'content'}
    _li! {_a 'headers', href: '_headers_', target: 'content'}
  end

  _div.attachments!

  _script src: '../../app.js'
  _.render '#attachments' do
    _Parts attachments: @attachments
  end
end
