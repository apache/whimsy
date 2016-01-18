#!/usr/local/bin/ruby2.3.0

require 'open3'
output, error, status = Open3.capture3 '/usr/local/bin/ruby2.3.0',
  Gem.bin_path('passenger', 'passenger-status')

require 'wunderbar'
_html do
  _h1 'Phusion Passenger Status'
  _pre output

  unless error.empty?
    _h2 'STDERR'
    _pre error
  end

  unless status.success?
    _h2 'Status'
    _pre status
  end
end
