#!/usr/bin/env ruby
# Utility functions Shane wrote (temporary)
$LOAD_PATH.unshift '/srv/whimsy/lib'
require 'whimsy/asf'
SCANDIR = "../www"

AUTHPATH = '/Users/curcuru/src/g/infrastructure-puppet/modules/subversion_server/files/authorization'
# Use various functions
def test()
#  auth = ASF::Authorization.initialize(file='asf', auth_path=AUTHPATH)
  # ASF::Authorization.each do |k,v|
  #   puts "#{k} = #{v.join(',')}"
  # end
end

p = ASF::Person['curcuru']
puts p.inspect
puts p.auth
puts "----"
puts p.public_name
puts "----"
puts p.member_emails