#!/usr/local/bin/ruby2.3.0

require 'open3'
require 'wunderbar'

if ENV['REQUEST_METHOD'] == 'POST'
  # not implemented yet.
  print "Status: 401 Unauthorized\r\n"
  print "WWW-Authenticate: Basic realm=\"ASF Members and Officers\"\r\n\r\n"
  exit
end

output, error, status = Open3.capture3 '/usr/local/bin/ruby2.3.0',
  Gem.bin_path('passenger', 'passenger-status')

_html do
  _style %{
    input[type=submit] {
      margin-left: 2em;
      padding: 5px 15px;
      background: #F00;
      color: #FFF;
      border: 2px solid #C00;
      font-weight: bold;
      font-size: larger;
      border-radius: 5px;
      cursor: pointer;
    }
  }

  _h1 'Phusion Passenger Status'

  sections = output.split(/^(---.*---)\n/)
  _pre sections.shift

  sections.each_slice(2) do |header, content|
    _h2 header

    if header.include? '--- Application groups ---'
      content.split("\n\n").each do |app|
        _pre app

        path = app[/\A(\/.*):/, 1]
        restart = File.join(path.untaint, "tmp/restart.txt") if path
        if restart and File.exist? restart
          _form method: 'post' do
             _input type: 'hidden', value: restart
             _input type: 'submit', value: 'restart'
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
