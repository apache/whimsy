#!/usr/bin/env ruby
# must agree with the Ruby version in PassengerDefaultRuby in passenger.conf

require 'bundler/setup'

require 'fileutils'
require 'open3'
require 'wunderbar'
require 'whimsy/asf'

# Allow override of user in test mode
if ENV['RACK_ENV'] == 'test'
    user = ASF::Person[ENV['USER']]
else
    user = ASF::LDAP.http_auth(ENV['HTTP_AUTHORIZATION'])
end

unless user
  print "Status: 401 Unauthorized\r\n"
  print "WWW-Authenticate: Basic realm=\"ASF Members and Officers\"\r\n\r\n"
  exit
end

# Must agree with the passenger Ruby version as above
output, error, status = Open3.capture3 `which ruby`.chomp,
  Gem.bin_path('passenger', 'passenger-status')

_html do
  _title 'Phusion Passenger Status'
  _style %{
    input[type=submit] {
      margin-left: 2em;
      padding: 5px 15px;
      background: #F2DEDE;
      color: #A94442;
      border: 2px solid #EBCCCC;
      font-weight: bold;
      font-size: larger;
      border-radius: 5px;
      cursor: pointer;
    }

    h1 a {
      text-decoration: none;
      outline: none;
    }

    .alert {
      padding: 15px;
      display: inline-block;
      margin-left: 1em;
      margin-bottom: 20px;
      border: 1px solid transparent;
      border-radius: 4px;
      color: #3C763D;
      background-color: #DFF0D8;
      border-color: #D6E9C6;
    }
  }

  _h1 do
    _a href: 'https://www.phusionpassenger.com/' do
      _img src: 'images/passenger.png'
    end

    _ 'Phusion Passenger Status'
  end

  sections = output.split(/^(---.*---)\n/)
  _pre sections.shift

  sections.each_slice(2) do |header, content|
    _h2 header

    if header.include? '--- Application groups ---'
      content.split("\n\n").each do |app|
        _pre app

        path = app[/\A(\/.*):/, 1]
        if user.asf_officer_or_member?
          restart = File.join(path, "tmp/restart.txt") if path
          if restart and File.exist? restart
            if _.post? and @restart == restart
              FileUtils.touch restart
              _span.alert "#{path} will restart on next request."
            else
              _form method: 'post' do
                 _input type: 'hidden', name: 'restart', value: restart
                 _input type: 'submit', value: 'restart'
              end
            end
          end
        end
      end
    else
      _pre content
    end
  end

  unless error.empty?
    _h2 'STDERR'
    _pre error
  end

  unless status.success?
    _h2 'Status'
    _pre status
  end
end
