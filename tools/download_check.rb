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
Checks a download page URL for compliance with ASF guidelines.


Note: the GUI interface is currently at www/members/download_check.cgi

=end

$LOAD_PATH.unshift '/srv/whimsy/lib'
require 'whimsy/asf'
require 'wunderbar'
require 'net/http'
require 'nokogiri'
require 'time'

=begin
Checks performed: (F=fatal, E=error, W=warn)
TBA
=end

$CLI = false
$VERBOSE = false

$ARCHIVE_CHECK = false
$ALWAYS_CHECK_LINKS = false
$NO_CHECK_LINKS = false
$NOFOLLOW = false # may be reset
$ALLOW_HTTP = false # http links generate Warning, not Error
$FAIL_FAST = false
$SHOW_LINKS = false

$VERSION = nil

# Check archives have hash and sig
$vercheck = {} # key = archive name, value = array of [type, hash/sig...]
# collect versions for summary display
$versions = Hash.new {|h1, k1| h1[k1] = Hash.new {|h2, k2| h2[k2] = Array.new} } # key = version, value = Hash, key = arch basename, value = array of [extensions]

# match an artifact
# TODO detect artifacts by URL as well if possible
# $1 = base, $2 = extension
# OOO SF links end in /download
ARTIFACT_RE = %r{/([^/]+\.(pom|crate|tar|tar\.xz|tar\.gz|deb|nbm|dmg|sh|zip|tgz|far|tar\.bz2|jar|whl|war|msi|exe|rar|rpm|nar|xml|vsix))([&?]action=download|/download)?$}

def init
  # build a list of validation errors
  @tests = []
  @fails = 0
  if $NO_CHECK_LINKS
    $NOFOLLOW = true
    I "Will not check links"
  elsif $ALWAYS_CHECK_LINKS
    I "Will check links even if download page has errors"
  else
    I "Will check links if download page has no errors"
  end
  I "Will %s archive.apache.org links in checks" % ($ARCHIVE_CHECK ? 'include' : 'not include')
end

# save the result of a test
def test(severity, txt)
  @tests << {severity => txt}
  unless severity == :I or severity == :W
    @fails += 1
    if $FAIL_FAST
      puts txt
      caller.each {|c| puts c}
      exit!
    end
  end
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
  @tests.map {|t| t[k]}.compact
end

# extract test entries with key k
def testentries(k)
  @tests.select {|t| t[k]}.compact
end

def showList(list, header)
  unless list.empty?
    _h2_ header
    _ul do
      list.each { |item| _li item }
    end
  end
end

def displayHTML
  fatals = tests(:F)
  errors = tests(:E)
  warns = tests(:W)

  if !fatals.empty?
    _h2_.bg_danger "The page at #{@url} failed our checks:"
  elsif !errors.empty?
    _h2_.bg_warning "The page at #{@url} has some problems:"
  elsif !warns.empty?
    _h2_.bg_warning "The page at #{@url} has some minor issues"
  else
    _h2_.bg_success "The page at #{@url} looks OK, thanks for using this service"
  end

  if @fails > 0
    showList(fatals, "Fatal errors:")
    showList(errors, "Errors:")
  end

  showList(warns, "Warnings:")

  _h2_ 'Tests performed'
  _ol do
    @tests.each { |t| t.map {|k, v| _li "#{k}: - #{v}"}}
  end
  _h4_ 'F: fatal, E: Error, W: warning, I: info (success)'
end

def check_url(url)
  uri = URI.parse(url)
  unless uri.scheme
    W "No scheme for URL #{url}, assuming http"
    uri = URI.parse("http:" + url)
  end
  return uri if %w{http https}.include? uri.scheme
  raise ArgumentError.new("Unexpected url: #{url}")
end

# Return uri, code|nil, response|error
def fetch_url(url, method=:head, depth=0, followRedirects=true) # string input
  uri = URI.parse(url)
  begin
    Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https') do |https|
      case method
      when :head
        request = Net::HTTP::Head.new(uri.request_uri)
      when :get
        request = Net::HTTP::Get.new(uri.request_uri)
      else
        raise "Invalid method #{method}"
      end
      response = https.request(request)
      if followRedirects and response.code =~ /^3\d\d/
        return uri, nil, "Too many redirects: #{depth} > 3" if depth > 3
        fetch_url response['location'], method, depth + 1 # string
      else
        return uri, response.code, response
      end
    end
  rescue Exception => e
    return uri, nil, e
  end
end

# Head an HTTP URL  => uri, code, response
def HEAD(url)
  puts ">> HEAD #{url}" if $VERBOSE
  fetch_url(url, :head)
end

# get an HTTP URL => response
def GET(url, followRedirects=true)
  puts ">> GET #{url}" if $VERBOSE
  fetch_url(url, :get, 0, followRedirects)[2]
end

# Check page exists => uri, code, response|nil
def check_head_3(path, severity = :E, log=true)
  uri, code, response = HEAD(path)
  if code == '403' # someone does not like Whimsy?
    W "HEAD #{path} - HTTP status: #{code} - retry"
    uri, code, response = HEAD(path)
  end
  unless code == '200'
    test(severity, "HEAD #{path} - HTTP status: #{code}") unless severity.nil?
    return uri, code, nil
  end
  I "Checked HEAD #{path} - OK (#{code})" if log
  return uri, code, response
end

# Check page exists => response or nil
def check_head(path, severity = :E, log=true)
  check_head_3(path, severity, log)[2]
end

# check page can be read => body or response or nil
def check_page(path, severity=:E, log=true, returnRes=false, followRedirects=true)
  response = GET(path, followRedirects)
  code = response.code || '?'
  unless code == '200' or (!followRedirects and code =~ /^3\d\d/)
    test(severity, "GET #{path} - HTTP status: #{code}") unless severity.nil?
    return nil
  end
  I "Checked GET #{path} - OK (#{code})" if log
  puts "Fetched #{path} - OK (#{code})" if $CLI
  return returnRes ? response : response.body
end

def WE(msg)
  if $ALLOW_HTTP
    W msg
  else
    E msg
  end
end

# returns www|archive, stem and the hash extension
def check_hash_loc(h, tlp)
  tlpQE = Regexp.escape(tlp) # in case of meta-chars
  tlpQE = "(?:ooo|#{tlpQE})" if tlp == 'openoffice'
  tlpQE = "(?:lucene|#{tlpQE})" if tlp == 'solr' # temporary override
  tlpQE = "(?:tubemq|inlong)" if tlp == 'inlong' # renamed
  tlpQE = "(?:hadoop/)?ozone" if tlp == 'ozone' # moved
  if h =~ %r{^(https?)://(?:(archive|www)\.)?apache\.org/dist/(?:incubator/)?#{tlpQE}/.*?([^/]+)\.(\w{3,6})$}
    WE "HTTPS! #{h}" unless $1 == 'https'
    return $2 || '', $3, $4 # allow for no host before apache.org
#     Allow // after .org (pulsar)
  elsif h =~ %r{^(https?)://(downloads)\.apache\.org//?(?:incubator/)?#{tlpQE}/.*?([^/]+)\.(\w{3,6})$}
    WE "HTTPS! #{h}" unless $1 == 'https'
    return $2, $3, $4
#   https://repo1.maven.org/maven2/org/apache/shiro/shiro-spring/1.1.0/shiro-spring-1.1.0.jar.asc
  elsif h =~ %r{^(https?)://repo1?\.(maven)(?:\.apache)?\.org/maven2/org/apache/#{tlpQE}/.+/([^/]+\.(?:jar|xml))\.(\w{3,6})$} # Maven
    WE "HTTPS! #{h}" unless $1 == 'https'
    W "Unexpected hash location #{h} for #{tlp}" unless ($vercheck[$3][0] rescue '') == 'maven'
    return $2, $3, $4
  else
    if h =~ %r{-bin-}
      W "Unexpected bin hash location #{h} for #{tlp}"
    else
      E "Unexpected hash location #{h} for #{tlp}"
    end
    nil
  end
end

# get the https? links as Array of [href, text]
def get_links(path, body, checkSpaces=false)
  doc = Nokogiri::HTML(body)
  nodeset = doc.css('a[href]')    # Get anchors w href attribute via css
  nodeset.map { |node|
    tmp = node.attribute("href").to_s
    href = tmp.strip
    if checkSpaces && tmp != href
      W "Spurious space(s) in '#{tmp}'"
    end
    if href =~ %r{^?Preferred=https?://}
      href = path + URI.decode_www_form_component(href)
    end
    text = node.text.gsub(/[[:space:]]+/, ' ').strip
    [href, text] unless href =~ %r{/httpcomponents.+/xdoc/downloads.xml} # breadcrumb link to source
  }.select {|x, _y| x =~ %r{^(https?:)?//} }
end

VERIFY_TEXT = [
  'the integrity of the downloaded files',
  'Verify Authenticity of Downloads',
  'verify the integrity', # commons has this as a link; perhaps try converting page to text only?
  'verify that checksums and signatures are correct',
  '#verifying-signature',
  'check that the download has completed OK',
  'You should verify your download',
  'downloads can be verified',
  'www.apache.org/info/verification',
  'www.apache.org/dyn/closer.cgi#verify',
  'verify your mirrored downloads',
  'verify your downloads',
  'verify the downloaded files',
  'All downloads should be verified',
  'verification instructions',
  ' encouraged to verify ',
  'To check a GPG signature',
  'To verify Hadoop',
  'Instructions for verifying your mirrored downloads', # fineract
  'How to verify the download?', # OOO
]

ALIASES = {
  'sig' => 'asc',
  'pgp' => 'asc',
  'gpg' => 'asc',
  'pgpasc' => 'asc',
  'sign' => 'asc',
  'signature' => 'asc',
  'signature(.asc)' => 'asc',
  'ascsignature' => 'asc',
  'pgpsignature' => 'asc',
  'pgpsignatures' => 'asc',
  'gpgsignature' => 'asc',
  'openpgpsignature' => 'asc',
}

# Need to be able to check if download is for a PMC or podling
# parameter is the website URL
# Also want to convert site to TLP
URL2TLP = {} # URL host to TLP conversion
URL2TLP['jspwiki-wiki'] = 'jspwiki' # https://jspwiki-wiki.apache.org/Wiki.jsp?page=Downloads
URL2TLP['xmlbeans'] = 'poi' # xmlbeans now being maintained by POI
PMCS = Set.new # is this a TLP?
ASF::Committee.pmcs.map do |p|
  site = p.site[%r{//(.+?)\.apache\.org}, 1]
  name = p.name
  URL2TLP[site] = name unless site == name
  PMCS << name
end

# Convert text reference to extension
# e.g. SHA256 => sha256; [SIG] => asc
def text2ext(txt)
  # need to strip twice to handle ' [ asc ] '
  # TODO: perhaps just remove all white-space?
  tmp = txt.downcase.strip.sub(%r{^\.}, '').sub(%r{^\[(.+)\]$}, '\1').sub('-', '').
        sub(/ ?(digest|checksum)/, '').sub(/ \(tar\.gz\)| \(zip\)| /, '').
        sub('(opens new window)', ''). # doris
        strip
  return 'sha256' if tmp =~ %r{\A[A-Fa-f0-9]{64}\z}
  return 'sha512' if tmp =~ %r{\A[A-Fa-f0-9]{128}\z}
  ALIASES[tmp] || tmp
end

# Suite: perform all the HTTP checks
def checkDownloadPage(path, tlp, version)
  begin
    _checkDownloadPage(path.strip, tlp, version)
  rescue Exception => e
    F e
    if $CLI
      p e
      puts e.backtrace
    end
  end
end

def _checkDownloadPage(path, tlp, version)
  isTLP = PMCS.include? tlp
  if version == ''
    I "Checking #{path} [#{tlp}] TLP #{isTLP} ..."
  else
    I "Checking #{path} [#{tlp}] TLP #{isTLP} for version #{version} only ..."
  end

  # check the main body
  if $ALLOW_JS
    body = `/srv/whimsy/tools/render-page.js #{path}`
  else
    body = check_page(path)
  end

  return unless body

  hasDisclaimer = body.gsub(%r{\s+}, ' ').include? 'Incubation is required of all newly accepted'

  if isTLP
    W "#{tlp} has Incubator disclaimer" if hasDisclaimer
  elsif hasDisclaimer
    I "#{tlp} has Incubator disclaimer"
  else
    E "#{tlp} does not have Incubator disclaimer"
  end

  # Some pages are mainly a single line (e.g. Hop)
  # This make matching the appropriate match context tricky without traversing the DOM
  body.scan(%r{(^.*?([^<>]+?(nightly|snapshot)[^<>]+?)).*$}i) do |m|
    m.each do |n|
      if n.size < 160
        if n =~ %r{API |/api/|-docs-} # snapshot docs Datasketches (Flink)?
          W "Found reference to NIGHTLY or SNAPSHOT docs?: #{n}"
        else
          # ignore trafficcontrol bugfix message
          unless n.include? "Fixed TO log warnings when generating snapshots" or
                 n.include? "Kafka Raft support for snapshots" or
                 n.include? "zkSnapshotC" or # ZooKeepeer
                 n.include? "/issues.apache.org/jira/browse/" # Daffodil
            W "Found reference to NIGHTLY or SNAPSHOT builds: #{n}"
          end
        end
        break
      end
    end
  end

  if body.include? 'dist.apache.org'
    E 'Page must not link to dist.apache.org'
  else
    I 'Page does not reference dist.apache.org'
  end

  if body.include? 'repository.apache.org'
    E 'Page must not link to repository.apache.org'
  else
    I 'Page does not reference repository.apache.org'
  end

  deprecated = Time.parse('2018-01-01')

  links = get_links(path, body, true)
  if links.size < 6 # source+binary * archive+sig+hash
    E "Page does not have enough links: #{links.size} < 6 -- perhaps it needs JavaScript?"
  end

  if $CLI
    puts "Checking link syntax"
    links.each do |h, t|
      if h =~ %r{^([a-z]{3,6})://}
        W "scheme? %s %s" % [h, t] unless %w(http https).include? $1
      else
        W "syntax? %s %s" % [h, t] unless h.start_with? '//'
      end
    end
  end
  if $SHOW_LINKS
    links.each {|l| p l}
  end

  tlpQE = Regexp.escape(tlp) # in case of meta-chars
  tlpQE = "(?:lucene|#{tlpQE})" if tlp == 'solr' # temporary override
  # check KEYS link
  # TODO: is location used by hc allowed, e.g.
  #   https://www.apache.org/dist/httpcomponents/httpclient/KEYS
  expurl = "https://[downloads.|www.]apache.org/[dist/][incubator/]#{tlp}/KEYS"
  expurlre = %r{^https://((www\.)?apache\.org/dist|downloads\.apache\.org)/(incubator/)?#{tlpQE}/KEYS$}
  keys = links.select {|h, _v| h =~ expurlre}
  if keys.size >= 1
    keyurl = keys.first.first
    keytext = keys.first[1]
    if keytext.include? 'KEYS'
      I 'Found KEYS link'
    else
      W "Found KEYS: '#{keytext}'"
    end
    check_head(keyurl, :E) # log
  else
    keys = links.select {|h, v| h.end_with? 'KEYS' || v.strip == 'KEYS' || v == 'KEYS file' || v == '[KEYS]'}
    if keys.size >= 1
      I 'Found KEYS link'
      keyurl = keys.first.first
      if keyurl =~ expurlre
        I "KEYS links to #{expurl} as expected"
      elsif keyurl =~ %r{^https://www\.apache\.org/dist/#{tlpQE}/[^/]+/KEYS$}
        W "KEYS: expected: #{expurl}\n             actual: #{keyurl}"
      elsif keyurl =~ %r{^https://downloads\.apache\.org/#{tlpQE}/[^/]+/KEYS$}
        W "KEYS: expected: #{expurl}\n             actual: #{keyurl}"
      else
        E "KEYS: expected: #{expurl}\n             actual: #{keyurl}"
      end
      check_head(keyurl, :E) # log
    else
      E 'Could not find KEYS link'
    end
  end

  hasGPGverify = false
  # Check if GPG verify has two parameters
  body.scan(%r{^.+gpg --verify.+$}) { |m|
    hasGPGverify = true
    unless m =~ %r{gpg --verify\s+\S+\.asc\s+\S+}
      W "gpg verify should specify second param: #{m.strip} see:\nhttps://www.apache.org/info/verification.html#specify_both"
    end
  }

  # Look for incorrect gpg qualifiers
  body.scan(%r{(gpg[[:space:]]+(.+?)(?:import|verify))}) { |m|
    pfx = m[1]
    unless pfx.sub(%r{<span[^>]*>}, '') == '--'
      W "gpg requires -- before qualifiers, not #{pfx.inspect}: #{m[0].strip}"
    end
  }

  # check for verify instructions
  bodytext = body.gsub(/\s+/, ' ') # single line
  if VERIFY_TEXT.any? {|text| bodytext.include? text}
    I 'Found reference to download verification'
  elsif hasGPGverify
    W 'Found reference to GPG verify; assuming this is part of download verification statement'
  else
    E 'Could not find statement of the need to verify downloads'
  end

  # check if page refers to md5sum
  body.scan(%r{^.+md5sum.+$}) {|m|
    W "Found md5sum: #{m.strip}"
  }

  links.each do |h, t|
    # These might also be direct links to mirrors
    if h =~ ARTIFACT_RE
      base = File.basename($1)
#         puts "base: " + base
      if $vercheck[base]  # might be two links to same archive
        W "Already seen link for #{base}"
      else
        ext = $2 # save for use after RE match
        $vercheck[base] = [h =~ %r{^https?://archive.apache.org/} ? 'archive' : (h =~ %r{https?://repo\d?\.maven(\.apache)?\.org/} ? 'maven' : 'live')]
        unless $vercheck[base].first == 'archive'
          stem = base[0..-(ext.size + 2)]
          # version must include '.', e.g. xxx-m.n.oyyy
#                 Apache_OpenOffice-SDK_4.1.10_Linux_x86-64_install-deb_en-US
          if stem =~ %r{^.+?[-_]v?(\d+(?:\.\d+)+)(.*)$}
            # $1 = version
            # $2 any suffix, e.g. -bin, -src (or other)
            ver = $1 # main version
            suff = $2
            # does version have a suffix such as beta1, M3 etc?
            # jmeter needs _ here; brpc uses rc02
            if suff =~ %r{^(-RC\d+|-rc\d+|-incubating|-ALPHA|[-.]?M\d+|[-~]?(alpha|beta)\d?(?:-\d)?)}
              ver += $1
            end
            $versions[ver][stem] << ext
          elsif stem =~ %r{netbeans-(\d+)-}i
            $versions[$1][stem] << ext
          else
            W "Cannot parse #{stem} for version"
          end
        end
      end
      # Text must include a '.' (So we don't check 'Source')
      if t.include?('.') and base != File.basename(t.sub(/[Mm]irrors? for /, '').strip)
        # text might be short version of link
        tmp = t.strip.sub(%r{.*/}, '') #
        if base == tmp
          W "Mismatch?: #{h} and '#{t}'"
        elsif base.end_with? tmp
          W "Mismatch?: #{h} and '#{tmp}'"
        elsif base.sub(/-bin\.|-src\./, '.').end_with? tmp
          W "Mismatch?: #{h} and '#{tmp}'"
        else
          W "Mismatch2: #{h}\n link: '#{base}'\n text: '#{tmp}'"
        end
      end
    end
  end

  links.each do |h, t|
    # Must occur before mirror check below
    # match all hashes and sigs here (invalid locations are detected later)
    if h =~ %r{^https?://.+?/([^/]+\.(asc|sha\d+|md5|sha|mds))$}
      base = File.basename($1)
      ext = $2
      stem = base[0..-(2 + ext.length)]
      if $vercheck[stem]
        $vercheck[stem] << ext
      else
        E "Bug: found hash #{h} for missing artifact #{stem}"
      end
      t.strip!
      next if t == '' # empire-db
      tmp = text2ext(t)
      next if ext == tmp # i.e. link is just the type or [TYPE]
      next if ext == 'sha' and tmp == 'sha1' # historic
      next if %w(sha256 md5 mds sha512 sha1).include?(ext) and %w(SHA digest Digest checksums).include?(t) # generic
      next if ext == 'mds' and (tmp == 'hashes' or t == 'Digests')
      if base != t
        if t == 'Download' # MXNet
          W "Mismatch: #{h} and '#{t}'"
        elsif not %w{checksum Hash}.include? t
          if h =~ %r{^https?://archive\.apache\.org/dist/} # only warn for archives
              W "Mismatch: #{h} and '#{t}'"
          else
              E "Mismatch: #{h} and '#{t}'"
          end
        end
      end
    end
  end


  # did we find all required elements?
  $vercheck.each do |k, w|
    v = w.dup
    typ = v.shift
    unless v.include? "asc" and v.any? {|e| e =~ /^sha\d+$/ or e == 'md5' or e == 'sha' or e == 'mds'}
      if typ == 'live'
        E "#{k} missing sig/hash: (found only: #{v.inspect})"
      elsif typ == 'archive' || typ == 'maven' # Maven does not include recent hash types; so warn only
        W "#{k} missing sig/hash: (found only: #{v.inspect})"
      else
        E "#{k} missing sig/hash: (found only: #{v.inspect}) TYPE=#{typ}"
      end
    end
    W "#{k} Prefer SHA* over MDS #{v.inspect}" if typ == 'live' && v.include?('mds') && v.none? {|e| e =~ /^sha\d+$/}
  end

  if @fails > 0 and not $ALWAYS_CHECK_LINKS
    W "** Not checking links **"
    $NOFOLLOW = true
  end

  # Still check links if versions not seen
  if $versions.size == 0
    E "Could not detect any artifact versions -- perhaps it needs JavaScript?"
  end

  # Check if the links can be read

  links.each do |h, t|
    if h =~ %r{\.(asc|sha256|sha512)$}
      host, _stem, _ext = check_hash_loc(h, tlp)
      if host == 'archive'
        if $ARCHIVE_CHECK
          check_head(h, :E) # log
        else
          I "Ignoring archived hash #{h}"
        end
      elsif host
        if $NOFOLLOW
          I "Skipping artifact hash #{h}"
        else
          uri, _code, _response = check_head_3(h, :E) # log
          unless uri.to_s == h
            h1 = h.sub(%r{//(www\.)?apache\.org/dist/}, '//downloads.apache.org/')
            unless uri.to_s == h1
              W "Redirected hash: #{h} => #{uri}"
            end
          end
        end
      else
        # will have been reported by check_hash_loc
      end
    elsif h =~ ARTIFACT_RE
      name = $1
      _ext = $2
      if h =~ %r{https?://archive\.apache\.org/}
        unless $ARCHIVE_CHECK
          I "Ignoring archived artifact #{h}"
          next
        end
      end
      # Ideally would like to check for use of closer.lua/.cgi, but some projects pre-populate the pages
      # TODO: would it help to check host against mirrors.list?
      if h =~ %r{https?://(www\.)?apache\.org/dist} or h =~ %r{https?://downloads.apache.org/}
        E "Must use mirror system #{h}"
        next
      elsif h =~ %r{https?://repo\d\.maven\.org/.+(-src|-source)}
        E "Must use mirror system for source #{h}"
        next
      end
      if $NOFOLLOW
        I "Skipping artifact #{h}"
        next
      end
      res = check_head(h, :E, false) # nolog
      next unless res
      # if HEAD returns content_type and length it's probably a direct link
      ct = res.content_type
      cl = res.content_length
      if ct and cl
        I "#{h} OK: #{ct} #{cl}"
      else # need to try to download the mirror page
        path = nil
        # action=download needs special handling
        if h =~ %r{^https?://(www\.)?apache\.org/dyn/.*action=download}
          res = check_page(h, :E, false, true, false)
          next unless res
          unless res.code =~ /^3\d\d$/
            E "Expected redirect, got #{res.code}"
            next
          end
          path = res['Location'] or E("Could not extract Location from #{h}")
        else
          bdy = check_page(h, :E, false)
          if bdy
            lks = get_links(path, bdy)
            lks.each do |l, _t|
              # Don't want to match archive server (closer.cgi defaults to it if file is not found)
              if l.end_with?(name) and l !~ %r{//archive\.apache\.org/}
                path = l
                break
              end
            end
            if bdy.include? 'The object is in our archive'
                W "File is archived: '#{name}' in page: '#{h}'"
                next
            end
          end
        end
        if path
          res = check_head(path, :E, false) # nolog
          next unless res
          ct = res.content_type
          cl = res.content_length
          if ct and cl
            I "OK: #{ct} #{cl} #{path}"
          elsif cl
            I "NAK: ct='#{ct}' cl='#{cl}' #{path}"
          else
            E "NAK: ct='#{ct}' cl='#{cl}' #{path}"
          end
        else
          E "Could not find link for '#{name}' in page: '#{h}' (missing)"
        end
      end
    elsif h =~ %r{\.(md5|sha\d*)$}
      host, stem, _ext = check_hash_loc(h, tlp)
      if $NOFOLLOW
        I "Skipping deprecated hash #{h}"
        next
      end
      if %w{www downloads archive maven}.include?(host) or host == ''
        next unless $ARCHIVE_CHECK or host != 'archive'
        res = check_head(h, :E, false) # nolog
        next unless res
        lastmod = res['last-modified']
        date = Time.parse(lastmod)
        # Check if older than 2018?
        if date < deprecated
          I "Deprecated hash found #{h} #{t}; however #{lastmod} is older than #{deprecated}"
          # OK
        else
          unless host == 'maven' and stem.end_with? '.jar' # Maven has yet to be upgraded...
            W "Deprecated hash found #{h} #{t} - do not use for current releases #{lastmod}"
          end
        end
      else
        E "Unhandled host: #{host} in #{h}"
      end
    elsif h =~ %r{/KEYS$} or t == 'KEYS'
      # already handled
    elsif h =~ %r{^https?://www\.apache\.org/?(licenses/.*|foundation/.*|events/.*)?$}
      # standard links
    elsif h =~ %r{https?://people.apache.org/phonebook.html}
    elsif h.start_with? 'https://cwiki.apache.org/confluence/'
      # Wiki
    elsif h.start_with? 'https://wiki.apache.org/'
      # Wiki
    elsif h.start_with? 'https://svn.apache.org/'
      #        E "Public download pages should not link to unreleased code: #{h}" # could be a sidebar/header link
    elsif h =~ %r{^https?://(archive|www)\.apache\.org/dist/}
      W "Not yet handled #{h} #{t}" unless h =~ /RELEASE[-_]NOTES/ or h =~ %r{^https?://archive.apache.org/dist/#{tlpQE}/}
    else
      # Ignore everything else?
    end
  end

end

def getTLP(url) # convert URL to TLP/podling
  if url =~ %r{^https?://cwiki\.apache\.org/confluence/display/(\S+)/}
    tlp = $1.downcase
  elsif url =~ %r{^https?://([^.]+)(\.incubator|\.us|\.eu)?\.apache\.org/}
    tlp = URL2TLP[$1] || $1
  elsif url =~ %r{^https?://([^.]+)\.openoffice\.org/}
    tlp = 'openoffice'
  else
    tlp = nil
    F "Unknown TLP for URL #{url}"
  end
  tlp
end

# Called by GUI when POST is pushed
def doPost(options)
  $ALWAYS_CHECK_LINKS = options[:checklinks]
  $NO_CHECK_LINKS = options[:nochecklinks]
  $ARCHIVE_CHECK = options[:archivecheck]
  init
  url = options[:url]
  tlp = options[:tlp]
  tlp = getTLP(url) if tlp == ''
  if tlp
    checkDownloadPage(url, tlp, options[:version])
  end
  displayHTML
end


if __FILE__ == $0
  $CLI = true
  $VERBOSE = true
  $ALWAYS_CHECK_LINKS = ARGV.delete '--always'
  $NO_CHECK_LINKS = ARGV.delete '--nolinks'
  $ARCHIVE_CHECK = ARGV.delete '--archivecheck'
  $ALLOW_HTTP = ARGV.delete '--http'
  $FAIL_FAST = ARGV.delete '--ff'
  $SHOW_LINKS = ARGV.delete '--show-links'
  $ALLOW_JS = ARGV.delete '--js-allow'

  # check for any unhandled options
  ARGV.each do |arg|
    if arg.start_with? '--'
      raise ArgumentError.new("Invalid option #{arg}; expecting always|nolinks|archivecheck|http|ff|show-links")
    end
  end

  init

  version = ''
  url = ARGV[0]
  if ARGV.size == 1
    tlp = getTLP(url)
  else
    tlp = ARGV[1]
    version = ARGV[2] || ''
  end

  checkDownloadPage(url, tlp, version)

  # display the test results as text
  puts ""
  puts "================="
  puts ""
  @tests.each { |t| t.map {|k, v| puts "#{k}: - #{v}"}}
  puts ""
  testentries(:W).each { |t| t.map {|k, v| puts "#{k}: - #{v}"}}
  testentries(:E).each { |t| t.map {|k, v| puts "#{k}: - #{v}"}}
  testentries(:F).each { |t| t.map {|k, v| puts "#{k}: - #{v}"}}
  puts ""

  # Only show in CLI version for now
  puts "Version summary"
  $versions.sort.each do |k, v|
    puts k
    v.sort.each do |l, w|
      puts "  #{l} #{w}"
    end
  end
  puts ""

  if @fails > 0
    puts "NAK: #{url} had #{@fails} errors"
  else
    puts "OK: #{url} passed all the tests"
  end
  puts ""

end
