#!/usr/bin/ruby
require 'wunderbar'

# the following is what infrastructure team sees:
print "Status: 200 OK\r\n"

# For human consumption:
_html do
  _h1 "Whimsy-Test Status"
  _p do
    _a 'Ping My Box', href: 'https://www.pingmybox.com/dashboard?location=470'
  end
end
