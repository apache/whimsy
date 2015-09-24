# To run with output going to STDOUT:
#
#   ruby examples/board.rb
#
# To run as a server:
#
#   ruby examples/board.rb --port=8080
#

require 'whimsy/asf'

_html do
  _table do
    _tr do
      _th 'id'
      _th 'name'
      _th 'mail'
    end

    ASF::Service.find('board').members.each do |person|
      _tr_ do
        _td person.id
        _td person.public_name
        _td person.mail.first
      end
    end
  end
end
