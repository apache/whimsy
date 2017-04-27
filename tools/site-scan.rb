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

# fetch uri, following redirects
def fetch(uri)
  uri = URI.parse(uri)
  Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https') do |http|
    request = Net::HTTP::Get.new(uri.request_uri)
    response = http.request(request)
    if response.code =~ /^3\d\d/
      fetch response['location']
    else
      return uri, request, response
    end
  end
end

def parse(site, name)
  uri, request, response = fetch(site)
  doc = Nokogiri::HTML(response.body)

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
    if a['href'] =~ %r{^https?://(www\.)?apache\.org/?$}
      img = a.at('img')
      if img
        data[:foundation] = uri + img['src'].strip
      else
        data[:foundation] = a.text 
      end
    end

    if a['href'] and a['href'].include? 'apache.org/events/'
      img = a.at('img')
      if img
        data[:events] = uri + img['src'].strip
      else
        data[:events] = uri + a['href'].strip
      end
    end

    a_text = a.text.downcase.strip
    $stderr.puts a_text if $verbose

    if a_text =~ /licenses?/ and a['href'].include? 'apache.org'
      data[:license] = uri + a['href'].strip 
    end

    if a_text == 'thanks'
      data[:thanks] = uri + a['href'].strip 
    end

    if a_text == 'security'
      data[:security] = uri + a['href'].strip 
    end

    if ['sponsorship', 'donate', 'sponsor apache','sponsoring apache'].include? a_text
      data[:sponsorship] = uri + a['href'].strip
    end
  end
  doc.traverse do |node|
    next unless node.is_a?(Nokogiri::XML::Text)
    # scrub is needed as some sites have invalid UTF-8 bytes
    txt = node.text.scrub
    # trademarks may appear twice. TODO use array?
    if txt =~ / Apache feather logo / and not data[:trademarks]
      t, p = getText(txt, node)
      data[:trademarks] = t
      data[:tradeparent] = p if p
    end
    if txt =~ /Copyright / or txt =~ /©/
      t, p = getText(txt, node)
      data[:copyright] = t
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
      txt = node.parent.parent.text.scrub
    else
      txt = node.parent.text.scrub
    end
    parent = true
  end
  # TODO strip extra text where possible.
  # Note: both copyright and trademark can be in same text (e.g. Cayenne)
  return txt.gsub(/\s+/, ' ').strip, parent
end

$verbose = ARGV.delete '--verbose'

results = {}

# Parse a single site given its URL
if ARGV.length == 2 and ARGV.first =~ /^https?:/
  site = ARGV.shift
  name = ARGV.shift
  results[name] = parse(site, name)
else
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
    results[committee.name] = parse(committee.site, committee.display_name)
  end
end
puts JSON.pretty_generate(results)
