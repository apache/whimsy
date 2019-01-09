#
# Layout for main page
# LH: list of messages
# RH: detail of selected message
#

_html do
  _title 'ASF Moderation Helper'

  _frameset cols: '45%, *' do
    _frame src: 'messages' # list of clickable messages must agree with server.rb
    _frame name: 'content' # name must agree with link target in message.js.rb
  end
end
