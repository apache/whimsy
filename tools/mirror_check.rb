#!/usr/bin/env ruby

#  Licensed to the Apache Software Foundation (ASF) under one or more
#  contributor license agreements.  See the NOTICE file distributed with
#  this work for additional information regarding copyright ownership.
#  The ASF licenses this file to You under the Apache License, Version 2.0
#  (the "License"); you may not use this file except in compliance with
#  the License.  You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.

=begin
Checks a mirror URL for compliance with ASF mirroring guidelines.

Derived partly from
https://svn.apache.org/repos/asf/infrastructure/site-tools/trunk/mirrors/check_mirror.pl

TODO this is a work in progress...

Ideally the causes of some of the problems should be reported ...

Note: the GUI interface is currently at www/members/mirror_check.cgi

=end

require 'wunderbar'
require 'net/http'

=begin
Checks performed: (F=fatal, E=error, W=warn)
F: zzz/time.txt is readable
F: its contents is a number followed by text
W: test whether time is more than 1 day old
W: test its content-type (missing or text/plain)
F: BASE is readable and non-empty
W: has html + body headers and body/html trailers
W: body matches m!<(img|IMG) (src|SRC)="/icons/!
E: check index against TLP list m!> ?$dir/?<!
E: tlp dir: check can be read (mirrors sometimes have incorrect protections)
W: 'favicon.ico' and 'zzz/' must both be in page
W: favicon.ico must appear after zzz/ to show folders first
E: 'harmony' should be redirected with 404
E: 'zzz/___' should generate 404
W: 'zzz/README' content-type text/plain
E: header must match /<h\d>Apache Software Foundation Distribution Meta-Directory</h\d>/
E: footer must match /This directory contains meta-data for the ASF mirroring system./
E: mirror-tests/ must exist
W: its files must not have content-encoding:
   1mb.img.7z 1mb.img.bz2 1mb.img.tar.gz 1mb.img.tgz 1mb.img.zip
W: zzz/mirror-tests/redirect-test/ should redirect to http://www.apache.org/ (302)

TODO - any more checks?

=end

URLMATCH = %r!^https?://[^/]+/(\S+/)?$!i
HTTPDIRS = %w(zzz/ zzz/mirror-tests/) # must exist
HDRMATCH = %r!<h\d>Apache Software Foundation Distribution Meta-Directory</h\d>! # must be on the zzz index page
FTRMATCH = %r!This directory contains meta-data for the ASF mirroring system.! # must be on the zzz index page
HASHDR =   %r!<html( [^>]+)?>.+?<body>!im
HASFTR =   %r!</body>.*?</html>!im

HTTPDIR = 'zzz/' # must appear in index page
HTTP404 = 'zzz/___'; # Non-existent URL; should generate 404
HTTPTEXT = 'zzz/README'; # text file (without extension) should generate Content-Type text/plain or none

MIRRORTEST = 'zzz/mirror-tests/';
MIRRORTEST_FILES = %w(1mb.img.7z 1mb.img.bz2 1mb.img.tar.gz 1mb.img.tgz 1mb.img.zip) # no Content-Encoding !

# save the result of a test
def test(severity, txt)
  @tests << {severity => txt}
  @fails+=1 unless severity == :I
end

def F(txt)
  test(:F, txt)
end

def E(txt)
  test(:E, txt)
end

def W(txt)
  test(:W, txt)
end

def I(txt)
  test(:I, txt)
end

# extract test entries with key k
def tests(k)
  @tests.map{|t| t[k]}.compact
end

# get an HTTP URL
def getHTTPHdrs(url)
  uri = URI.parse(url)
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = uri.scheme == 'https'
  request = Net::HTTP::Head.new(uri.request_uri)
  http.request(request)
end

def check_redirect(base, page, expectedLocation, severity=:W, expectedStatus = "302", log=true)
  path = base + page
  response = getHTTPHdrs(path)
  if response.code != expectedStatus
    test severity, "HTTP status #{response.code} for '#{path}'" unless severity == nil
    return nil
  end
  if response['location'] != expectedLocation
    test severity, "HTTP location #{response['location']} for '#{path}' - expected '#{expectedLocation}'" unless severity == nil
    return nil
  end
  I "Fetched #{path} - redirected OK to #{response['location']}" if log
  response
end

def check_CT(base, page, severity=:E, expectedStatus = "200")
  path = base + page
  response = getHTTPHdrs(path)
  if response.code != expectedStatus
    test severity, "HTTP status #{response.code} for '#{path}'" unless severity == nil
    return nil
  end
  ct = response['Content-Type'] || 'unknown'
  ce = response['Content-Encoding']
  # TODO also check CT - some mirrors return text/plain for img??
  if ce
    W "Checking #{path} - Content-Type: #{ct} WARN: Content-Encoding: #{ce}"
  else
    I "Checking #{path} - Content-Type: #{ct}"
  end
end

# get an HTTP URL=> response
def getHTTP(url)
  uri = URI.parse(url)
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = uri.scheme == 'https'
  request = Net::HTTP::Get.new(uri.request_uri)
  http.request(request)
end

# check page can be read => body
def check_page(base, page, severity=:E, expectedStatus="200", log=true)
  path = base + page
  response = getHTTP(path)
  code = response.code ||  '?'
  if code != expectedStatus
    test(severity, "Fetched #{path} - HTTP status: #{code} expected: #{expectedStatus}") unless severity == nil
    return nil
  end
  I "Fetched #{path} - OK" if log
  response.body
end

def checkIndex(page, type)
  asfData = @pages[type]
  links = parseIndexPage(page)
  if type == :tlps
    fav = links.index('favicon.ico')
    zzz = links.index('zzz')
    if fav and zzz
      if fav < zzz
        W "Index for #{type}: incorrect #{type} page order - found favicon.ico before zzz/; folders should be listed before files"
      else
        I "Index for #{type}: found favicon.ico and zzz/ in the page in the correct order (i.e. folders are listed before files)"
      end
    else
      W "Index for #{type}: expected to find favicon.ico #{fav} and zzz/ #{zzz} in the page, but at least one is missing"
    end
  end
  links.each {|l|
    W "Index for #{type}: the link #{l} is not shown on ASF site" unless asfData.include? l
  }
  asfData.each {|l|
    W "Index for #{type}: the link #{l} is not shown on the mirror site" unless links.include? l or l == 'openoffice'
  }
end

# nginx <tr><td><a href="activemq/" title="activemq">activemq/</a></td><td>-</td><td>2019-Nov-25 18:00</td></tr>
# ASF <tr><td valign="top"><img src="/icons/folder.gif" alt="[DIR]"></td><td><a href="accumulo/">accumulo/</a></td><td align="right">2019-08-07 23:42  </td><td align="right">  - </td><td>&nbsp;</td></tr>


# parse an HTTP server Index page => array of file/folder names
def parseIndexPage(page)
  folders = []
  # ASF main page references currently look like this: <a href="abdera/">abdera/</a>
  # the Perl script looked for this match: m!> ?$dir/?<!
  links = page.scan(%r{<a href=['"]([.a-z0-9-]+)/?['"](?: title=['"][.a-z0-9-]+/?['"])?>([.a-z0-9-]+)/?</a>})
  links.each { |l|
    if l[1] == l[0]
      folders << l[1]
    end
  }
  folders
end
# Check page has sensible headers and footers
def checkHdrFtr(path, body)
  hasHTMLhdr = HASHDR.match(body)
  hasHTMLftr = HASFTR.match(body)
  if hasHTMLhdr
    if hasHTMLftr
      I "#{path} has header and footer"
    else
      W "#{path} is incomplete - no footer found"
    end
  else # no header
    if hasHTMLftr
      W "#{path} is incomplete - no header found"
    else
      W "#{path} is incomplete - no header or footer found"
    end
  end
end

# Suite: perform all the HTTP checks
def checkHTTP(base)
  # We don't check the pattern on the form for two reasons:
  # - not all browsers support it
  # - allows the input to be more flexible

  # Fix up the URL
  base.strip!
  base += '/' unless base.end_with? '/'
  base = 'http://' + base unless base.start_with? 'http'
  # Now check the syntax:

  I "Checking #{base} ..."

  unless URLMATCH.match(base)
    F "Invalid URL syntax: #{base}"
    return
  end

  setup

  response = getHTTPHdrs(base)
  server = response['server']
  if server =~ /Apache/
    I "Server: #{server}"
  else
    W "Server: '#{server}' - expected 'Apache' in server response"
  end

  # Check the mirror time (and that zzz/ is readable)
  time = check_page(base, 'zzz/time.txt', severity = :F)
  if time
    match = /^(\d+) \S+$/.match(time)
    if match
      now = Time.now.to_i
      stamp = match[1].to_i
      age = (now - stamp)/60 # minutes
      if age > 60*24
        W "Mirror is over 1 day old: #{age} minutes"
      else
        I "Mirror is less than 1 day old: #{age} minutes"
      end
    else
      F "Invalid time.txt contents: #{time}"
    end
  else
    return # cannot process further (already recorded the error
  end

  # check the main body
  body = check_page(base, '')
  checkHdrFtr(base, body)
  if %r{<(img|IMG) (src|SRC)="/icons/}.match(body)
    I "Index page has icons as expected"
  else
    W "Missing or unexpected img icon tags"
  end
  checkIndex(body, :tlps)

  ibody = check_page(base, 'incubator/')
  checkHdrFtr(base+'incubator/', ibody)
  checkIndex(ibody, :podlings)

  check_page(base, 'harmony/', :E, expectedStatus="404")

  zbody = check_page(base, HTTPDIR)
# Not sure this is useful on its own anymore
# It was originally used to detect sites with advertising wrappers,
# but most recent examples have been tables around directory listings
# which is obviously OK as it does not affect the user experience.
#  if  %r{<table}i.match(zbody)
#    W "#{HTTPDIR} - TABLE detected"
#  else
#    I "#{HTTPDIR} - No TABLE detected, OK"
#  end
  checkHdrFtr(base+HTTPDIR, zbody)
  if HDRMATCH.match(zbody)
    I "Index page for #{HTTPDIR} contains the expected header text"
  else
    W "Index page for #{HTTPDIR} does not contain the expected header text"
  end
  if FTRMATCH.match(zbody)
    I "Index page for #{HTTPDIR} contains the expected footer text"
  else
    W "Index page for #{HTTPDIR} does not contain the expected footer text"
  end

  check_page(base,HTTP404,:E, expectedStatus="404")

  # Check that archives don't have Content-Encoding
  MIRRORTEST_FILES.each do |file|
    check_CT(base, MIRRORTEST + file)
  end
  check_redirect(base, 'zzz/mirror-tests/redirect-test/xyz', 'http://www.apache.org/')
end

def init
  # build a list of validation errors
  @tests = []
  @fails = 0
end

def setup
  tlps = parseIndexPage(check_page('https://downloads.apache.org/','',:F,"200",log=false))
  podlings = parseIndexPage(check_page('https://downloads.apache.org/incubator/','',:F,"200",false))
  @pages = {:tlps => tlps, :podlings => podlings}
end

def showList(list, header)
  unless list.empty?
    _h2_ header
    _ul do
      list.each { |item| _li item }
    end
  end
end

def display
  fatals = tests(:F)
  errors = tests(:E)
  warns = tests(:W)

  if !fatals.empty?
    _h2_.bg_danger "The mirror at #@url failed our checks:"
  elsif !errors.empty?
    _h2_.bg_warning "The mirror at #@url has some problems:"
  elsif !warns.empty?
    _h2_.bg_warning "The mirror at #@url has some minor issues"
  else
    _h2_.bg_success "The mirror at #@url looks OK, thanks for using this service"
  end

  if @fails > 0
    showList(fatals, "Fatal errors:")
    showList(errors, "Errors:")
    showList(warns, "Warnings:")
    # Cannot easily copy/paste URLs; use layout suitable for copy/paste into e.g. JIRA issue/e-mail
    _p do
      _ 'Please see the Apache mirror configuration instructions [1] for further details on configuring your mirror server.'
    end
    _p do
    _ '[1] '
      _a 'http://www.apache.org/info/how-to-mirror.html#Configuration', href: 'http://www.apache.org/info/how-to-mirror.html#Configuration'
    end
  end

  _h2_ 'Tests performed'
  _ol do
    @tests.each { |t| t.map{|k,v| _li "#{k}: - #{v}"}}
  end
  _h4_ 'F: fatal, E: Error, W: warning, I: info (success)'
end

# Called by GUI when POST is pushed
def doPost(url)
  init
  checkHTTP(url)
  display
end

if __FILE__ == $0
  init
  url = ""+ARGV[0] || "localhost" # easier to test in an IDE
  checkHTTP(url)
  # display the test results
  @tests.each { |t| t.map{|k, v| puts "#{k}: - #{v}"}}
  if @fails > 0
    puts "#{url} had #{@fails} errors"
  else
    puts "#{url} passed all the tests"
  end
end
