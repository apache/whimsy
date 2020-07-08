#!/usr/bin/env ruby

#
# Generate a whimsy.local version of the deployed whimsy configuration
#
# Example usage:
#  ruby vhosttest.rb <infra-puppet-checkout> | ruby mkconf.rb /private/etc/apache2/other/whimsy.conf
# or if you have ssh access to the whimsy host:
# ruby mkconf.rb /private/etc/apache2/other/whimsy.conf

if STDIN.tty?
  conf = `ssh whimsy.apache.org cat \
    /etc/apache2/sites-enabled/*-whimsy-vm-443.conf`
else
  conf = STDIN.read
end

conf.sub! 'VirtualHost *:443', 'VirtualHost *:80'
conf.sub! 'ServerName whimsy.apache.org', 'ServerName whimsy.local'

conf.gsub! 'ServerAlias', '## ServerAlias'

conf.gsub! /(\A|\n)\s*RemoteIPHeader.*/, ''

conf.gsub! /\n\s*PassengerDefault.*/, ''
conf.gsub! /\n\s*PassengerUser.*/, ''
conf.gsub! /\n\s*PassengerGroup.*/, ''

conf.gsub! /\n\s*SSL.*/, ''
conf.gsub! /\n\s*## SSL.*/, ''
conf.gsub! "SetEnv HTTPS", "# SetEnv HTTPS"

conf.gsub! '/x1/srv/whimsy', '/srv/whimsy'

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
