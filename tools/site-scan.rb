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

def squash(text)
  text.scrub.gsub(/[[:space:]]+/, ' ').strip
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
        data[:foundation] = squash(a.text) 
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
