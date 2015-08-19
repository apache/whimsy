#!/usr/bin/ruby1.9.1

require 'whimsy/asf'
require 'wunderbar'

user = ASF::Person.new($USER)
unless user.asf_member? or ASF.pmc_chairs.include? user or $USER=='ea'
  print "Status: 401 Unauthorized\r\n"
  print "WWW-Authenticate: Basic realm=\"ASF Members and Officers\"\r\n\r\n"
  exit
end

ASF::Person.preload('cn')

_html do
  _h1 "public names: LDAP vs ICLA.txt"

  _table do
    _tr do
      _th "availid"
      _th "icla.txt"
      _th "LDAP cn"
    end

    ASF::ICLA.new.each do |id, name, email|
      next if id == 'notinavail'
      person = ASF::Person.find(id)
      if person.public_name != name
        _tr_ do
          _td id
          _td name
          _td person.public_name
        end
      end
    end
  end
end
