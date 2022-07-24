#!/usr/bin/env ruby
# Scans Apache project homepages and captures text|urls for common links
# Gathers data that can be used to check for policy compliance:
#   https://www.apache.org/foundation/marks/pmcs#navigation
#   http://www.apache.org/events/README.txt
#   See Also: lib/whimsy/sitestandards.rb
#
# Makes no value judgements.  Simply extracts raw data for offline analysis.
$LOAD_PATH.unshift '/srv/whimsy/lib'
require 'net/http'
require 'nokogiri'
require 'json'
require 'whimsy/asf'
require 'whimsy/cache'
require 'whimsy/sitestandards'
require_relative 'asf-site-check'

$stdout.sync = true

# Normalize spaces in text runs
def squash(text)
  return text.scrub.gsub(/[[:space:]]+/, ' ').strip
end

# Get text from a node; use parent if text does not appear to be complete
# This is used when scanning for some links that may
#   be in an image or other commonly related node on websites
def getText(txt, node, match=/Apache Software Foundation/i)
  parent = nil # debug to show where parent needed to be fetched
  if txt !~ match # have we got all the text?
    if node.parent.name == 'a' # e.g. whimsical. such parents don't have extra text.
      newnode = node.parent.parent
    else
      newnode = node.parent
    end
    # ensure <br> is treated as a separator when extracting the combined text
    newnode.css('br').each { |br| br.replace(" ") }
    txt = squash(newnode.text)
    parent = true
  end
  return txt, parent
end

# Parse an Apache project website and return text|urls that match our checks
# @return Hash of symbols: text|url found from a check made
# @see SiteStandards for definitions of what we should scan for (in general)
def parse(id, site, name)
  data = {}
  SiteStandards::COMMON_CHECKS.each_key do |k|
    data[k.to_sym] = nil
  end
  data[:display_name] = name
  data[:uri] = site
  uri = URI.parse(site)
  begin
    Socket.getaddrinfo(uri.host, uri.scheme)
  rescue SocketError => se
    data[:errors] = se.message
    return data
  end
  begin
    uri, response, status = $cache.get(site.to_s)
  rescue IOError => ioe
    data[:errors] = ioe.message
    return data
  end
  puts "#{id} #{uri} #{status}"
  # Bail and return if getting the site returns an error code
  if response.respond_to? :code and response.code =~ /^[45]/
    data[:errors] = "cache.get(#{site}) error code #{response.code}"
    return data
  end
  doc = Nokogiri::HTML(response)
  data[:uri] = uri.to_s

  # FIRST: scan each link's a_href to see if we need to capture it
  doc.css('a').each do |a|
    # Normalize the text and href for our capture purposes
    a_href = a['href'].to_s.strip
    a_text = a.text.downcase.strip
    $stderr.puts "#{a_text} #{a_href}" if $verbose

    # Check the href urls for some patterns
    if a_href =~ SiteStandards::COMMON_CHECKS['foundation'][SiteStandards::CHECK_CAPTURE]
      img = a.at('img')
      if img
        # use the title (hover text) in preference to the source
        data[:foundation] = img['title'] ? squash(img['title']) : uri + img['src'].strip
      else
        data[:foundation] = squash(a.text)
      end
    end

    if a_href =~ SiteStandards::COMMON_CHECKS['events'][SiteStandards::CHECK_CAPTURE]
      img = a.at('img')
      if img
        data[:events] = uri + img['src'].strip
      else
        data[:events] = uri + a_href
      end
    end

    # Check the a_text strings for other patterns
    # Note this is an unusual case
    if (a_text =~ SiteStandards::COMMON_CHECKS['license'][SiteStandards::CHECK_TEXT]) and
        (a_href =~ SiteStandards::COMMON_CHECKS['license'][SiteStandards::CHECK_CAPTURE])
      begin
        data[:license] = uri + a_href
      rescue StandardError
        data[:license] = a_href
      end
    end

    %w(thanks security sponsorship privacy).each do |check|
      if a_text =~ SiteStandards::COMMON_CHECKS[check][SiteStandards::CHECK_CAPTURE]
        begin
          data[check.to_sym] = uri + a_href
        rescue StandardError
          data[check.to_sym] = a_href
        end
      end
    end
  end

  # SECOND: scan each text node to match and capture
  doc.traverse do |node|
    next unless node.is_a?(Nokogiri::XML::Text)
    txt = squash(node.text)
    # allow override if phrase looks good
    if (txt =~ SiteStandards::COMMON_CHECKS['trademarks'][SiteStandards::CHECK_CAPTURE] and not data[:trademarks]) or
        txt =~ /are trademarks of [Tt]he Apache Software/
      t, p = getText(txt, node)
      # drop previous text if it looks like Copyright sentence
      data[:trademarks] = t.sub(/^.*?Copyright .+? Foundation[.]?/, '').strip
      data[:tradeparent] = p if p
    end
    if txt =~ SiteStandards::COMMON_CHECKS['copyright'][SiteStandards::CHECK_CAPTURE]
      t, p = getText(txt, node)
      # drop text around the Copyright (or the symbol)
      data[:copyright] = t.sub(/^.*?((Copyright|©) .+? Foundation[.]?).*/, '\1').strip
      data[:copyparent] = p if p
    end
    # Note we also check for incubator disclaimer (immaterial of tlp|podling)
    if txt =~ SiteStandards::PODLING_CHECKS['disclaimer'][SiteStandards::CHECK_CAPTURE]
      t, _p = getText(txt, node, / is an effort undergoing/)
      data[:disclaimer] = t
    end
  end
  # THIRD: see if an image has been uploaded
  data[:image] = ASF::SiteImage.find(id)

  # Check for resource loading from non-ASF domains
  cmd = ['node', '/srv/whimsy/tools/scan-page.js', site]
  out, err, status = exec_with_timeout(cmd, 30)
  if status
    ext_urls = out.split("\n").reject {|x| ASFDOMAIN.asfhost? x}.tally
    resources = ext_urls.values.sum
    data[:resources] = "Found #{resources} external resources: #{ext_urls}"
  else
    data[:resources] = err
  end

  #  TODO: does not find js references such as:
  #  ga.src = ('https:' == document.location.protocol ? 'https://ssl' : 'http://www') + '.google-analytics.com/ga.js';
  return data
end

require 'timeout'
# the node script appears to stall sometimes, so apply a timeout
def exec_with_timeout(cmd, timeout)
  begin
    # stdout, stderr pipes
    rout, wout = IO.pipe
    rerr, werr = IO.pipe
    stdout, stderr = nil
    status = false

    pid = Process.spawn(*cmd, pgroup: true, :out => wout, :err => werr)

    Timeout.timeout(timeout) do
      Process.waitpid(pid)
      # close write ends so we can read from them
      wout.close
      werr.close

      stdout = rout.readlines.join
      stderr = rerr.readlines.join
      status = true
    end

  rescue Timeout::Error
    # Try to determine why the kill does not tidy the chrome processes
    # Also whether a kill was actually issued!
    puts "WARN: timeout scanning #{cmd[-1]} #{pid}"
    $stderr.puts "WARN:  #{Time.now} timeout scanning #{cmd[-1]} #{pid}"
    stderr = 'Timeout'
    # try using less drastic kill
    Process.kill(-2, pid) # INT
    Process.kill(-15, pid) # TERM
    Process.detach(pid)
  ensure
    wout.close unless wout.closed?
    werr.close unless werr.closed?
    # dispose the read ends of the pipes
    rout.close
    rerr.close
  end
  return stdout, stderr, status
end

#########################################################################
# Main execution begins here
results = {}
podlings = {}
$cache = Cache.new(dir: 'site-scan')
$verbose = ARGV.delete '--verbose'

puts "Started: #{Time.now}"  # must agree with site-scan monitor

# USAGE:
# site-scan.rb https://whimsical.apache.org [Whimsy] [whimsy-scan.json] - to scan one project
# site-scan.rb [project-output.json] [podlings-output.json] [projname podlingname ...]
# If additional projname|podlingname are provided, only scans those sites
if ARGV.first =~ /^https?:\/\/\w/
  # Scan a single URL provided by user
  site = ARGV.shift
  name = ARGV.shift || site[/\/(\w[^.]*)/, 1].capitalize
  output_projects = ARGV.shift
  results[name] = parse(name, site, name)
else
  # Gather output filenames (if any) and scan various projects
  if ARGV.first =~ %r{[./]} # have we a file name?
    output_projects = ARGV.shift
    if ARGV.first =~ %r{[./]} # have we another file name?
      output_podlings = ARGV.shift
    else
      output_podlings = nil
    end
  else
    output_projects = nil
  end

  # Scan committees, including non-pmcs
  ASF::Committee.load_committee_info
  committees = (ASF::Committee.pmcs + ASF::Committee.nonpmcs).uniq
  committees.sort_by {|committee| committee.name}.each do |committee|
    next unless committee.site
    # if more parameters specified, parse only those names
    if ARGV.length > 0
      next unless ARGV.include? committee.name
    end
    results[committee.name] = parse(committee.name, committee.site, committee.display_name)
  end

  # Scan podlings that have a website
  ASF::Podling.list.each do |podling|
    if podling.status == 'current' and podling.podlingStatus[:website]
      # if more parameters specified, parse only those names
      if ARGV.length > 0
        next unless ARGV.include? podling.name
      end
      podlings[podling.name] = parse(podling.name, podling.podlingStatus[:website], podling.display_name)
    end
  end
end

# Output all results
if output_projects
  File.write(output_projects, JSON.pretty_generate(results))
else
  puts JSON.pretty_generate(results)
end
if output_podlings
  File.write(output_podlings, JSON.pretty_generate(podlings))
else
  puts JSON.pretty_generate(podlings)
end

puts "Ended: #{Time.now}" # must agree with site-scan monitor
