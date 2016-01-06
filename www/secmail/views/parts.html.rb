#
# Display the list of parts for a given message
#

_html do
  _link rel: 'stylesheet', type: 'text/css', href: '../../secmail.css'

  _ul_ do
    _li! {_a 'text', href: '_body_', target: 'content'}
    _li! {_a 'headers', href: '_headers_', target: 'content'}
    _li! {_a 'raw', href: '_raw_', target: 'content'}
  end

  _div.attachments!

  _script src: '../../app.js'
  _.render '#attachments' do
    _Parts attachments: @attachments, headers: @headers
  end
end
