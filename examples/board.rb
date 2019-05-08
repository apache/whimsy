# To run with output going to STDOUT:
#
#   ruby examples/board.rb
#
# To run as a server:
#
#   ruby examples/board.rb --port=8080
#
# To install on a server that supports CGI:
#
#   ruby examples/board.rb --install=/Users/rubys/Sites/

$LOAD_PATH.unshift '/srv/whimsy/lib'
require 'whimsy/asf'

_html do
  _h1_ 'List of ASF board members'

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
