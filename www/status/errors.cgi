#!/usr/bin/ruby

#
# Fetch and parse the Ping My Box error log
#

require 'wunderbar'
require 'uri'
require 'yaml'
require 'net/http'
require 'time'

# fetch status
uri = URI.parse('https://www.pingmybox.com/api.pmb?what=errors&id=470')
http = Net::HTTP.new(uri.host, uri.port)
http.use_ssl = true
request = Net::HTTP::Get.new(uri.request_uri)
response = http.request(request)

# extract time, pinger, and exception from response
exceptions = YAML.load(response.body).map do |hash| 
  exception = hash['debug'][/Caught exception: .*?: (.*)/m, 1].strip
  [Time.at(hash['time']), hash['pinger'], exception]
end

# produce table
_html do
  _link rel: 'stylesheet', href: 'css/bootstrap.min.css'
  _h1 'Error Log'

  _table.table do
    _tr_ do
      _th 'Time'
      _th 'Pinger'
      _th 'Status'
      _th 'Error'
    end

    exceptions.sort.reverse.each do |time, pinger, text|
      color = (text.include?('HTTP/1.1 3') ? 'warning' : 'danger')
      _tr_ class: color do
        _td time.iso8601
        _td align: 'right' do
          _a pinger, href:
            "https://www.pingmybox.com/pings?location=470&pinger=#{pinger}"
        end
        _td text[/^HTTP\/1.1 (\d+)/, 1] 
        _td text.sub(/^HTTP\/1.1 \d+/, '')
      end
    end
  end

  _p do
    _a 'raw log', href: uri.to_s
  end
end


