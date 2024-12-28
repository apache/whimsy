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
    newnode.css('br').each { |br| br.replace(' ') }
    txt = squash(newnode.text)
    parent = true
  end
  return txt, parent
end

# helper for multiple events
# TODO should we show them all?
def save_events(data, value)
  prev = data[:events]
  if prev and prev != value
    puts "Events: already have '#{prev}', not storing '#{value}'"
  else
    data[:events] = value
  end
end

# Extract link text, skipping invisible stuff (assumed to be a class ending with 'sr-only')
def get_link_text(anode)
  bits = []
  anode.traverse do |node|
    if node.name == 'text'
      bits << node.text unless node.parent.name == 'span' and  node.parent.attribute('class')&.value&.end_with? 'sr-only'
    end
end
  bits.join(' ')
end

# Parse an Apache project website and return text|urls that match our checks
# @return Hash of symbols: text|url found from a check made
# @see SiteStandards for definitions of what we should scan for (in general)
def parse(id, site, name, podling=false)
  show_anyway = Time.now.gmtime.strftime('%H') == '08' # show suppressed errors once a day
  data = {}
  # force https to avoid issue with cache (sites should use https anyway)
  site.sub!(%r{^http:},'https:')
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
  if $saveparse
    file = File.join('/tmp',"site-scan_#{$$}.txt")
    File.write(file, doc.to_s)
    $stderr.puts "Wrote parsed input to #{file}"
  end
  data[:uri] = uri.to_s

  subpages = Hash.new
  # FIRST: scan each link's a_href to see if we need to capture it
  # also capture script src for events, and some page refs for podlings
  doc.traverse do |a|

    if a.name == 'script'
      a_src = a['src'].to_s.strip
      if a_src =~ SiteStandards::COMMON_CHECKS['events'][SiteStandards::CHECK_CAPTURE]
        save_events data, uri + a_src
      end
    end

    next unless a.name == 'a'

    # Normalize the text and href for our capture purposes
    a_href = a['href'].to_s.strip
    a_text = get_link_text(a) # Not down-cased yet
    $stderr.puts "#{a_text.inspect} #{a_href}" if $verbose

    # Check the href urls for some patterns
    if a_href =~ SiteStandards::COMMON_CHECKS['foundation'][SiteStandards::CHECK_CAPTURE]
      img = a.at('img')
      if img
        # use the title (hover text) in preference to the source
        data[:foundation] = img['title'] ? squash(img['title']) : uri + img['src'].strip
      else
        data[:foundation] = squash(a_text)
      end
    end

    if a_href =~ SiteStandards::COMMON_CHECKS['events'][SiteStandards::CHECK_CAPTURE]
      # Hack to ignore hidden links on main site
      save_events data, uri + a_href unless a['class'] == 'visible-home' and uri.path != '/'
    end

    # Check the a_text strings for other patterns
    a_text = a_text.downcase.strip # needs to be downcased here
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
    unless a_href =~ %r{^(#|mailto:)}
      begin
        if a_href =~ %r{^https?://} # no need to rebase this
          site2 = URI.parse(a_href.gsub(' ','%20').gsub('|', '%7C')) # needs to be a URI
        else
          site2 = URI.join(site,a_href.gsub(' ','%20').gsub('|', '%7C')) # HACK
        end
        if site2.host == uri.host and site2.path.size > 2
          subpages[site2.to_s] = a
        end
      rescue StandardError => e
        if show_anyway or !a_href.include?('fineract.gateway.scarf.sh/{version}') # reported, but not yet fixed, so suppress noise
          $stderr.puts "#{id}: Bad a_href #{a_href} #{e}"
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

  # Brief scan of initial sub-pages to look for disclaimers and downloads
  hasdisclaimer = 0
  nodisclaimer = []
  subpages.each do |subpage, anchor|
    if podling
      begin
        uri, response, status = $cache.get(subpage)
        if uri&.to_s == subpage or uri&.to_s == subpage + '/'
          puts "#{id} #{uri} #{status}"
        else
          puts "#{id} #{subpage} => #{uri} #{status}"
        end
        unless status == 'error'
          if response =~ SiteStandards::PODLING_CHECKS['disclaimer'][SiteStandards::CHECK_CAPTURE]
            hasdisclaimer += 1
          else
            nodisclaimer << subpage
          end
        else
          unless %w(nlpcraft).include? id # reported, but unresponsive, so suppress noise
            $stderr.puts "#{id} #{subpage} => #{uri} #{status} '#{anchor.text.strip}'"
          end
        end
      rescue URI::InvalidURIError
        # ignore
      end
    end
  end
  if nodisclaimer.size > 0
    data[:disclaimers] = [hasdisclaimer, nodisclaimer]
  end
  # Show potential download pages
  data[:downloads] = subpages.select{|k,_v| k =~ %r{download|release|install|dlcdn\.apache\.org|dyn/closer}i}

  # THIRD: see if an image has been uploaded
  data[:image] = ASF::SiteImage.find(id)

  # Check for resource loading from non-ASF domains
  if $skipresourcecheck
    data[:resources] = 'Not checked'
  else
    cmd = ['node', '/srv/whimsy/tools/scan-page.js', site]
    out, err, status = exec_with_timeout(cmd, 60)
    if status
      ext_urls = out.split("\n").reject {|x| ASFDOMAIN.asfhost? x}.tally
      resources = ext_urls.values.sum
      data[:resources] = "Found #{resources} external resources: #{ext_urls}"
    else
      data[:resources] = err
    end
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
      status = $?.success?
      # close write ends so we can read from them
      wout.close
      werr.close

      stdout = rout.readlines.join
      stderr = rerr.readlines.join
      unless status
        $stderr.puts "WARN:  #{Time.now} failed scanning #{cmd} #{pid} #{stderr}"
        stderr = 'Scanning failed'
      end

    end

  rescue Timeout::Error
    # Try to determine why the kill does not tidy the chrome processes
    # Also whether a kill was actually issued!
    puts "WARN: timeout scanning #{cmd[-1]} #{pid}"
    $stderr.puts "WARN:  #{Time.now} timeout scanning #{cmd[-1]} #{pid}"
    stderr = 'Timeout'
    ret=''
    # Try to show process tree
    cmd = "ps -lfg #{$$}"
    begin
      $stderr.puts "WARN:  #{Time.now} #{cmd}:"
      $stderr.puts `#{cmd}`
      reaper = Process.detach(pid) # ensure the process is reaped
      # kill -pid responds with EINVAL - invalid argument
      $stderr.puts "WARN:  #{Time.now} about to kill -15 #{pid}"
      ret = Process.kill(-15, pid) # SIGTERM
      $stderr.puts "WARN:  #{Time.now} sent kill -15 #{pid} ret=#{ret}"

      thrd = reaper.join 30 # allow some time for process to exit

      if thrd # original process has finished
        $stderr.puts  "WARN:  #{Time.now} process completed #{thrd.value}"
      else # not yet finished, try a stronger kill
        $stderr.puts "WARN:  #{Time.now} about to kill -9 #{pid}"
        ret = Process.kill(-9, pid) # SIGKILL
        $stderr.puts "WARN:  #{Time.now} sent kill -9 #{pid} ret=#{ret}"
        thrd = reaper.join 5 # allow some time for process to exit
        if thrd
          $stderr.puts  "WARN:  #{Time.now} process completed #{thrd.value}"
        else
          $stderr.puts "ERROR:  #{Time.now} failed to kill -9 #{pid}"
        end
      end
    rescue StandardError => e
      $stderr.puts "WARN:  #{Time.now} ret=#{ret} exception: #{e}"
    end
    $stderr.puts "WARN:  #{Time.now} #{cmd}:"
    $stderr.puts `#{cmd}`
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
$cache = Cache.new(dir: ENV['SITE_SCAN_CACHE'] || 'site-scan')
$verbose = ARGV.delete '--verbose'
$saveparse = ARGV.delete '--saveparse'
$skipresourcecheck = ARGV.delete '--noresource'
sites_checked = 0
sites_failed = 0

k = ARGV.select {|k| k.start_with? '-'}
if k.size > 0
  raise "Unexpected options: #{k} (valid: verbose, saveparse, noresource)"
end

puts "Started: #{Time.now}"  # must agree with site-scan monitor

# USAGE:
# site-scan.rb https://whimsical.apache.org [Whimsy] [whimsy-scan.json] - to scan one project
# site-scan.rb [project-output.json] [podlings-output.json] [projname podlingname ...]
# If additional projname|podlingname are provided, only scans those sites
if ARGV.first =~ /^https?:\/\/\w/
  # Scan a single URL provided by user
  podling = ARGV.delete('--podling')
  site = ARGV.shift.dup # needs to be unfrozen
  name = ARGV.shift || site[/\/(\w[^.]*)/, 1].capitalize
  output_projects = ARGV.shift
  results[name] = parse(name, site, name, podling)
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
    results[committee.name]['nonpmc'] = committee.nonpmc?
    sites_checked += 1
    sites_failed += 1 unless results[committee.name][:resources].start_with? 'Found'
    # Don't keep checking unnecessarily
    $skipresourcecheck = (sites_failed > 10 or (sites_failed > 3 and sites_failed == sites_checked))
  end

  # Scan podlings that have a website
  ASF::Podling.list.sort_by(&:name).each do |podling|
    if podling.status == 'current' and podling.podlingStatus[:website]
      # if more parameters specified, parse only those names
      if ARGV.length > 0
        next unless ARGV.include? podling.name
      end
      podlings[podling.name] = parse(podling.name, podling.podlingStatus[:website], podling.display_name, true)
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
