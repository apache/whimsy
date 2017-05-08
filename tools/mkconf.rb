#
# Generate a whimsy.local version of the deployed whimsy configuration
#

require 'rbconfig'

conf = `ssh whimsy-vm4.apache.org cat \
  /etc/apache2/sites-enabled/*-whimsy-vm-443.conf`

conf.sub! 'VirtualHost *:443', 'VirtualHost *:80'
conf.sub! 'ServerName whimsy.apache.org', 'ServerName whimsy.local'

conf.gsub! /\n\s*RemoteIPHeader.*/, ''

conf.gsub! /\n\s*PassengerDefault.*/, ''

conf.gsub! /\n\s*SSL.*/, ''
conf.gsub! /\n\s*## SSL.*/, ''
conf.gsub! "SetEnv HTTPS", "# SetEnv HTTPS"

conf.gsub! '/x1/srv/whimsy', File.expand_path('../..', __FILE__)

conf.sub! /^SetEnv PATH .*/ do |line|
  line[/PATH\s+(\/.*?):/, 1] = '/usr/local/bin'

  line
end

conf.sub! 'wss://', 'ws://'

if ARGV.empty?
  puts conf
else
  ARGV.each do |arg|
    File.write arg, conf
  end
end
