#!/usr/bin/env ruby
$LOAD_PATH.unshift File.realpath(File.expand_path('../../lib', __FILE__))

#
# Scans committee pages for compliance with requirements and recommendations:
#   https://www.apache.org/foundation/marks/pmcs#navigation
#   http://www.apache.org/events/README.txt
#
# Makes no value judgements.  Simply extracts raw data for offline analysis.
#

require 'whimsy/asf'
require 'net/http'
require 'nokogiri'
require 'json'

# Simple cache for site pages
class Cache
  # Don't bother checking cache entries that are younger (seconds)
  # This is mainly intended for local testing
  attr_accessor :minage
  attr_accessor :enabled

  def initialize(dir: '/tmp/site-scan-cache', minage: 3000, enabled: true)
    @dir = dir
    @enabled = enabled
    @minage = minage # default to 50 mins as cron job runs every hour
    begin
      FileUtils.mkdir_p dir
    rescue
      @enabled = false
    end
  end

  def get(id, url)
    if not @enabled
      uri, res = fetch(url)
      return uri, res.body, 'nocache'
    end
    age, lastmod, uri, data = read_cache(id)
    if age < minage
      return uri, data, 'recent' # we have a recent cache entry
    end
    if data and lastmod
      # let's see if the page has been updated
      uri, res = fetch(url, {'If-Modified-Since' => lastmod})
      if res.is_a?(Net::HTTPSuccess)
        write_cache(id, uri, res)
        return uri, res.body, 'updated'
      elsif res.is_a?(Net::HTTPNotModified)
        path = makepath(id)
        mtime = Time.now
        File.utime(mtime, mtime, path) # show we checked the page
        return uri, data, 'unchanged'
      else
        return nil, res, 'error'
      end
    else
      uri, res = fetch(url)
      write_cache(id, uri, res)
      return uri, res.body, data ? 'no last mod' : 'missing'
    end
  end

  private

  # fetch uri, following redirects
  def fetch(uri, options={}, depth=1)
    if depth > 5
      raise IOError.new("Too many redirects (#{depth}) detected at #{url}")
    end
    uri = URI.parse(uri)
    Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https') do |http|
      request = Net::HTTP::Get.new(uri.request_uri)
      options.each do |k,v|
        request[k] = v
      end
      response = http.request(request)
      if response.code == '304' # Not modified
        return uri, response      
      elsif response.code =~ /^3\d\d/ # assume redirect
        fetch response['location'], options, depth+1
      else
        return uri, response
      end
    end
  end

  # File cache contains last modified followed by the data
  # The file mod time can be used to skip any checks for recently updated files
  def write_cache(id, uri, res)
    path = makepath(id)
    open path, 'wb' do |io|
      io.puts res['Last-Modified']
      io.puts uri
      io.write res.body
    end
  end

  # return age, last-modified, uri, data
  def read_cache(id)
    path = makepath(id)
    mtime = File.stat(path).mtime rescue nil
    last = nil
    data = nil
    uri = nil
    if mtime
      open path, 'rb' do |io|
        last = io.gets.chomp
        uri = URI.parse(io.gets.chomp)
        data = io.read
#       Fri, 12 May 2017 14:10:23 GMT
#       123456789012345678901234567890
        last = nil unless last.length > 25
      end
    end
    
    return Time.now - (mtime ? mtime : Time.new(0)), last, uri, data
  end

  def makepath(id)
    name = id.gsub /[^\w]/, '_'
    File.join @dir, "#{name}.html"
  end

end

def squash(text)
  text.scrub.gsub(/[[:space:]]+/, ' ').strip
end

#########################################################################

def parse(id, site, name)
  uri, response, status = $cache.get(id, site)
  $stderr.puts "#{id} #{uri} #{status}"
  doc = Nokogiri::HTML(response)

  # default data
  data = {
    display_name: name,
    uri: uri.to_s,
    events: nil,
    foundation: nil,
    license: nil,
    sponsorship: nil,
    security: nil,
    trademarks: nil,
    copyright: nil,
  }

  # scan each link
  doc.css('a').each do |a|

    # check the link targets
    a_href = a['href'].to_s.strip

    if a_href =~ %r{^https?://(www\.)?apache\.org/?$}
      img = a.at('img')
      if img
        # use the title (hover text) in preference to the source
        data[:foundation] = img['title'] ? squash(img['title']) : uri + img['src'].strip
      else
        data[:foundation] = squash(a.text) 
      end
    end

    if a_href.include? 'apache.org/events/'
      img = a.at('img')
      if img
        data[:events] = uri + img['src'].strip
      else
        data[:events] = uri + a_href
      end
    end

    # check the link text
    a_text = a.text.downcase.strip
    $stderr.puts a_text if $verbose

    if a_text =~ /licenses?/ and a_href.include? 'apache.org'
      data[:license] = uri + a_href 
    end

    if a_text == 'thanks'
      data[:thanks] = uri + a_href 
    end

    if a_text == 'security'
      data[:security] = uri + a_href 
    end

    if ['sponsorship', 'donate', 'sponsor apache','sponsoring apache'].include? a_text
      data[:sponsorship] = uri + a_href
    end
  end

  # Now scan the page text
  doc.traverse do |node|
    next unless node.is_a?(Nokogiri::XML::Text)

    txt = squash(node.text)

    # allow override if phrase looks good
    if (txt =~ /\btrademarks\b/  and not data[:trademarks]) or txt =~/are trademarks of [Tt]he Apache Software/
      t, p = getText(txt, node)
      # drop previous text if it looks like Copyright sentence
      data[:trademarks] = t.sub(/^.*?Copyright .+? Foundation[.]?/,'').strip
      data[:tradeparent] = p if p
    end
    if txt =~ /Copyright / or txt =~ /©/
      t, p = getText(txt, node)
      # drop text around the Copyright (or the symbol)
      data[:copyright] = t.sub(/^.*?((Copyright|©) .+? Foundation[.]?).*/,'\1').strip
      data[:copyparent] = p if p
    end
  end
  return data
end

# get the text; use parent if text does not appear to be complete
def getText(txt, node)
  parent = nil # debug to show where parent needed to be fetched
  if not txt =~ /Apache Software Foundation/i # have we got all the text?
    if node.parent.name == 'a' # e.g. whimsical. such parents don't have extra text.
      newnode = node.parent.parent
    else
      newnode = node.parent
    end
    # ensure <br> is treated as a separator when extracting the combined text
    newnode.css('br').each{ |br| br.replace(" ") }
    txt = squash(newnode.text)
    parent = true
  end
  return txt, parent
end

$verbose = ARGV.delete '--verbose'

results = {}

$cache = Cache.new()

# Parse a single site given its URL
if ARGV.length == 2 and ARGV.first =~ /^https?:/
  site = ARGV.shift
  name = ARGV.shift
  results[name] = parse(name, site, name)
else
  if ARGV.first =~ %r{[./]} # have we a file name?
    outfile = ARGV.shift
  else
    outfile = nil
  end
  # scan all committees, including non-pmcs
  ASF::Committee.load_committee_info
  committees = (ASF::Committee.list + ASF::Committee.nonpmcs).uniq
  
  committees.sort_by {|committee| committee.name}.each do |committee|
    next unless committee.site
    # if parameters specified, parse only those names
    if ARGV.length > 0
      next unless ARGV.include? committee.name
    end

    # fetch, parse committee site
    results[committee.name] = parse(committee.name, committee.site, committee.display_name)
  end
end
if outfile
  File.write(outfile, JSON.pretty_generate(results))
else
  puts JSON.pretty_generate(results)
end
