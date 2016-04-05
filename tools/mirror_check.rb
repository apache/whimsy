#!/usr/bin/env ruby

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
E: 'harmony' should be redirected with 301
E: 'zzz/___' should generate 404
W: 'zzz/README' content-type text/plain
E: header must match /<h\d>Apache Software Foundation Distribution Meta-Directory</h\d>/
E: footer must match /This directory contains meta-data for the ASF mirroring system./
E: mirror-tests/ must exist
W: its files must not have content-encoding:
   1mb.img.7z 1mb.img.bz2 1mb.img.tar.gz 1mb.img.tgz 1mb.img.zip

TODO - any more checks?

=end

$SAFE = 1

DEFAULT = 'http://localhost/dist/'

URLPAT = '^https?://[^/]+/(\S+/)?$'
HTTPDIRS = %w(zzz/ mirror-tests/) # must exist
HDRMATCH = %r!<h\d>Apache Software Foundation Distribution Meta-Directory</h\d>! # must be on the zzz index page
FTRMATCH = %r!This directory contains meta-data for the ASF mirroring system.! # must be on the zzz index page
HASHDR =   %r!<html( [^>]+)?>.+?<body>!im
HASFTR =   %r!</body>.*?</html>!im

HTTPDIR = 'zzz/' # must appear in index page
HTTP404 = 'zzz/___'; # Non-existent URL; should generate 404
HTTPTEXT = 'zzz/README'; # text file (without extension) should generate Content-Type text/plain or none

MIRRORTEST = 'mirror-tests/';
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
  url.untaint
  uri = URI.parse(url)
  http = Net::HTTP.new(uri.host, uri.port)
  request = Net::HTTP::Head.new(uri.request_uri)
  http.request(request)
end

def check_CT(base, page, severity=:E, expectedStatus = 200)
  path = base + page
  response = getHTTPHdrs(path)
  if response.code.to_i != expectedStatus
    test severity, "HTTP status #{response.code} for #{path}" unless severity == nil
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
  url.untaint
  uri = URI.parse(url)
  http = Net::HTTP.new(uri.host, uri.port)
  if uri.scheme == 'https'
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE 
  end
  request = Net::HTTP::Get.new(uri.request_uri)
  http.request(request)
end

# check page can be read => body
def check_page(base, page, severity=:E, expectedStatus="200")
  path = base + page
  response = getHTTP(path)
  code = response.code ||  '?'
  if code != expectedStatus
    test(severity, "Fetched #{path} - HTTP status: #{code} expected: #{expectedStatus}") unless severity == nil
    return nil
  end
  I "Fetched #{path} - OK"
  response.body
end

def checkIndex(page, type)
  if type == :tlps
    fav = page.match('favicon.ico')
    zzz = page.match('zzz/')
    if fav.length == 1 and zzz.length == 1
      if fav.begin(0) < zzz.begin(0)
        W "Incorrect page order - found favicon.ico before zzz/; folders should be listed before files"
      else
        I "Found favicon.ico and zzz/ in the page in the correct order (i.e. folders are listed before files)"
      end
    else
      W "Expecting to find favicon.ico and zzz/ in the page"
    end
  end
  asfData = @pages[type]
  links = parseIndexPage(page)
  links.each {|l|
    W "Index #{type} the link #{l} is not shown on ASF site" unless asfData.include? l
  }
  asfData.each {|l|
    W "Index #{type} the link #{l} is not shown on SUT" unless links.include? l    
  }  
end

# parse an HTTP server Index page => array of file/folder names
def parseIndexPage(page)
  folders = []
  # ASF main page references currently look like this: <a href="abdera/">abdera/</a>
  # the Perl script looked for this match: m!> ?$dir/?<!
  links = page.scan(%r{<a href=['"]([.a-z0-9-]+)/?['"]>([.a-z0-9-]+)/?</a>})
  links.each { |l|
    if l[1] == l[0]
      folders << l[1]
    else
      print "Mistmatched names: #{l}\n"
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
  I "Checking #{base} ..."

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

  check_page(base, 'harmony/', :E, expectedStatus="301")

  zbody = check_page(base, HTTPDIR)
  if  %r{<table}i.match(zbody)
    W "#{HTTPDIR} - TABLE detected"
  else
    I "#{HTTPDIR} - No TABLE detected, OK"
  end
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
end

def init
  # build a list of validation errors
  @tests = []
  @fails = 0
  tlps = parseIndexPage(check_page('http://www.apache.org/dist/',''))
  podlings = parseIndexPage(check_page('http://www.apache.org/dist/incubator/',''))
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
    _h2_ "The mirror at #@url failed our checks:"
  elsif !errors.empty?    
    _h2_ "The mirror at #@url has some problems:"
  elsif !warns.empty?
    _h2_ "The mirror at #@url has some minor issues"
  else
    _h2_ "The mirror at #@url looks OK, thanks for using this service"
  end

  if @fails > 0
    showList(fatals, "Fatal errors:")
    showList(errors, "Errors:")
    showList(warns, "Warnings:")
    _p do
      _ 'Please see the'
      _a 'Apache mirror configuration instructions', href: 'http://www.apache.org/info/how-to-mirror.html#Configuration'
      _ 'for further details on configuring your mirror server.'
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
  url = ARGV[0] || DEFAULT
  url += '/' unless url.end_with? '/'
  checkHTTP(url)
  # display the test results
  @tests.each { |t| t.map{|k, v| puts "#{k}: - #{v}"}} 
  if @fails > 0
    puts "#{url} had #{@fails} errors"
  else
    puts "#{url} passed all the tests"
  end
end
