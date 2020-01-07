#!/usr/bin/env ruby

# Check a URL

require 'net/http'

def HEAD(url)
  url.untaint
  uri = URI.parse(url)
  unless uri.scheme
    puts "No scheme for URL #{url}, assuming http"
    uri = URI.parse("http:"+url)
  end
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = uri.scheme == 'https'
  request = Net::HTTP::Head.new(uri.request_uri)
  http.request(request)
end

response = HEAD 'http://apache.claz.org/jspwiki/2.11.0.M6/source/jspwiki-builder-2.11.0.M6-source-release.zip'
p response
p response.code
