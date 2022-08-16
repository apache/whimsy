#!/usr/bin/env ruby
$LOAD_PATH.unshift '/srv/whimsy/lib'

require 'whimsy/asf'
require 'date'
require 'builder'
require 'ostruct'
require 'nokogiri'
require 'net/https'
require 'fileutils'
require 'wunderbar'

Wunderbar.log_level = 'info' unless Wunderbar.logger.info? # try not to override CLI flags

# Add datestamp to log messages (progname is not needed as each prog has its own logfile)
Wunderbar.logger.formatter = proc { |severity, datetime, progname, msg|
      "_#{severity} #{datetime} #{msg}\n"
    }

# for monitoring purposes
at_exit do
  if $! and not $!.instance_of? SystemExit
    msg = "#{$!.backtrace.first} #{$!.message}" rescue $!
    puts "\n*** Exception #{$!.class} : #{msg} ***"
  end
  Wunderbar.info "Finished #{__FILE__}"
end

Wunderbar.info "Starting #{__FILE__}"

# destination directory
SITE_MINUTES = ASF::Config.get(:board_minutes) ||
  File.expand_path(File.join('..', '..', 'www', 'board', 'minutes'), __FILE__)

# list of SVN resources needed
SVN_SITE_RECORDS_MINUTES = ASF::SVN['minutes']
BOARD = ASF::SVN['foundation_board']

KEEP = ARGV.delete '--keep' # keep obsolete files?

force = ARGV.delete '--force' # rerun regardless

NOSTAMP = ARGV.delete '--nostamp' # don't add dynamic timestamp to pages (for debug compares)

DUMP_AGENDA = ARGV.delete '--dump_agenda' # output agenda details

STAMP = (NOSTAMP ? DateTime.new(1970) :  DateTime.now).strftime '%Y-%m-%d %H:%M'

YYYYMMDD = ARGV.shift || '20*' # Allow override of minutes to process

TIME_DIFF = (ARGV.shift || '300').to_i # Allow override of seconds of time diff (WHIMSY-204) for testing

MINUTES_NAME = "board_minutes_#{YYYYMMDD}.txt"
MINUTES_PATH = File.join(SVN_SITE_RECORDS_MINUTES, "*", MINUTES_NAME)

Wunderbar.info "Processing minutes matching #{MINUTES_NAME}"

INDEX_FILE = "#{SITE_MINUTES}/index.html"

# quick exit if everything is up to date
if File.exist? INDEX_FILE
  input = Dir[MINUTES_PATH,
    "#{BOARD}/board_minutes_20*.txt"].
    map {|name| File.stat(name).mtime}.
    push(File.stat(__FILE__).mtime, ASF.library_mtime).
    max

  indexmtime = File.stat(INDEX_FILE).mtime
  diff = indexmtime - input
  Wunderbar.info "Most recent update: #{input}"
  Wunderbar.info "Index file update:  #{indexmtime} Diff: #{diff}"
  # WHIMSY-204: allow for update window
  # TODO: consider storing actual update check time
  if diff >= TIME_DIFF
    Wunderbar.info "All up to date! (#{TIME_DIFF})"
    unless force
      # Add stamp to index page
      page = File.read(INDEX_FILE)
      open(INDEX_FILE, 'w') { |file|
        # must agree with section.add_child
        file.write page.sub(/(Last run: )\d{4}-\d\d-\d\d \d\d:\d\d(\. The data is extracted from a list of)/,"\\1#{STAMP}\\2")
      }
      exit
    end
  end
end

Wunderbar.info "Updating files"

# mapping of committee names to canonical names (generally from ldap)
canonical = Hash.new {|hash, name| name}

# extract podling information
site = {}
ASF::Podling.list.each do |podling|
  if podling.display_name.downcase != podling.name
    canonical[podling.display_name.downcase] = podling.name
  end

  if podling.status == 'graduated' and podling.enddate
    next if Date.today - podling.enddate > 90
  end

  site[podling.name] = {
    name:   podling.display_name,
    status: podling.status,
    link:   "http://incubator.apache.org/projects/#{podling.name}.html",
    text:   podling.description
  }
end

# get site information
DATAURI = 'https://whimsy.apache.org/public/committee-info.json'
local_copy = File.expand_path('../../www/public/committee-info.json', __FILE__)
if File.exist?(local_copy) && (Time.now - File.stat(local_copy).mtime < 3600)
  Wunderbar.info "Using #{local_copy}"
  cinfo = JSON.parse(File.read(local_copy))
else
  Wunderbar.info "Fetching remote copy of committee-info.json"
  response = Net::HTTP.get_response(URI(DATAURI))
  response.value() # Raises error if not OK
  cinfo = JSON.parse(response.body)
end

cinfo['committees'].each do |id,v|
  if v['display_name'].downcase != id
    canonical[v['display_name'].downcase] = id
  end
  site[id] = {:name => v['display_name'], :link => v['site'], :text => v['description']}
end

# parse the calendar for layout info (note: hack for &raquo and &nbsp;)
CALENDAR = URI.parse 'https://www.apache.org/foundation/board/calendar.html'
http = Net::HTTP.new(CALENDAR.host, CALENDAR.port)
http.use_ssl = true
http.verify_mode = OpenSSL::SSL::VERIFY_NONE
get = Net::HTTP::Get.new CALENDAR.request_uri
$calendar = Nokogiri::HTML(http.request(get).body.gsub('&raquo', '&#187;').gsub('&nbsp;', '&#160;'))

# Link to headerlink css
link = Nokogiri::XML::Node.new "link", $calendar
link.set_attribute('rel', 'stylesheet')
link.set_attribute('href', 'https://www.apache.org/css/headerlink.css')
$calendar.at('head').add_child(link)

# add some style
style = Nokogiri::XML::Node.new "style", $calendar
style.content = %{
  table {
    border: 1px solid #ccc;
    margin-botton: 10px;
    width: 100%;
    border-collapse: collapse;
    border-spacing: 0;
  }

  tbody th, tbody td {
    border-bottom: 1px solid #ccc;
    border-top: 1px solid #ccc;
    padding: 0.2em 1em;
  }

  pre.report {
    color: black;
    font-family: Consolas,monospace
  }
}
$calendar.at('head').add_child(style)

# Make links absolute
%w(a img link script).each do |name|
  $calendar.search(name).each do |element|
    element['href'] = (CALENDAR + element['href'].strip).to_s if element['href']
    element['src'] = (CALENDAR + element['src'].strip).to_s if element['src']
  end
end

# handle project name changes
# see also www/board/minutes/.htaccess
# also see parse (Executive) Officer Reports ca. line 670
def name_changes(title)
  title.sub! 'Ace', 'ACE' # WHIMSY-31
  title.sub! 'ADF Faces', 'MyFaces' # via Trinidad
  title.sub! 'Amber', 'Oltu'
  title.sub! 'Apache/TCL', 'Tcl'
  title.sub! 'Argus', 'Ranger'
  title.sub! 'ASF Rep. for W3C', 'W3C Relations'
  title.sub! 'Bean Validation', 'BVal'
  title.sub! 'BeanValidation', 'BVal'
  title.sub! 'Bluesky', 'BlueSky'
  title.sub! 'BRPC', 'brpc'
  title.sub! 'Callback', 'Cordova'
  title.sub! 'Conferences', 'Conference Planning'
  title.sub! 'Cxx Standard Library', 'C++ Standard Library'
  title.sub! 'Deft', 'AWF'
  title.sub! 'DLab', 'DataLab'
  title.sub! 'Distributed Release Audit Tool (DRAT)', 'DRAT'
  title.sub! 'Dolphin Scheduler', 'DolphinScheduler' # board_minutes_2019_11_20.txt
  title.sub! 'Easyant', 'EasyAnt'
  title.sub! 'Empire-DB', 'Empire-db'
  title.sub! 'Fleece', 'Johnzon'
  title.sub! 'Geroniomo', 'Geronimo'
  title.sub! 'iBatis', 'iBATIS'
  title.sub! 'infrastructure', 'Infrastructure'
  title.sub! 'ISIS', 'Isis'
  title.sub! 'IVY', 'Ivy'
  title.sub! 'JackRabbit', 'Jackrabbit'
  title.sub! 'James', 'JAMES'
  title.sub! 'Java Community Process', 'JCP'
  title.sub! 'JSecurity', 'Shiro'
  title.sub! 'Juice', 'JuiCE'
  title.sub! 'log4php', 'Log4php'
  title.sub! 'Lucene.NET', 'Lucene.Net'
  title.sub! 'lucene4c', 'Lucene4c'
  title.sub! 'MesaTEE', 'Teaclave'
  title.sub! 'Ode', 'ODE'
  title.sub! 'ODFToolkit', 'ODF Toolkit'
  title.sub! 'Open for Business', 'OFBiz'
  title.sub! 'TomEE (OpenEJB)', 'TomEE'
  title.sub! 'OpenEJB', 'TomEE'
  title.sub! 'Openmeetings', 'OpenMeetings'
  title.sub! 'OpenOffice.org', 'OpenOffice'
  title.sub! 'Optiq', 'Calcite'
  title.sub! 'Orc', 'ORC'
  title.sub! 'Oscar', 'Felix'
  title.sub! 'PonyMail', 'Pony Mail'
  title.sub! 'PRC', 'Public Relations'
  title.sub! 'Public Relations Commitee', 'Public Relations'
  title.sub! 'Quarks', 'Edgent'
  title.sub! 'SensSoft', 'Flagon'
  title.sub! 'Servicecomb', 'ServiceComb'
  title.sub! 'Singa', 'SINGA'
  title.sub! 'Socialsite', 'SocialSite'
  title.sub! 'stdcxx', 'C++ Standard Library'
  title.sub! 'STDCXX', 'C++ Standard Library'
  title.sub! 'Steve', 'STeVe'
  title.sub! 'Stratosphere', 'Flink'
  title.sub! 'SystemML', 'SystemDS'
  title.sub! 'TCL', 'Tcl'
  title.sub! 'TubeMQ', 'InLong'
  title.sub! 'Web services', 'Web Services'
  title.sub! 'Zest', 'Polygene'
  title.sub! "Infrastructure (President's)", 'Infrastructure'
  title.sub! %r{\bKi\b}, 'Shiro'
  title.sub! %r{^HTTPD?$}, 'HTTP Server'
  title.sub! %r{^Infrastructure .*}, 'Infrastructure'
  title.sub! %r{^Labs .*}, 'Labs'
  title.sub! %r{^Logging$}, 'Logging Services'
  title.sub! %r{APR$}, 'Portable Runtime (APR)'
  title.sub! %r{CeltiX[Ff]ire}, 'CXF'
  title.sub! %r{Fund[- ][rR]aising}, 'Fundraising'
  title.sub! %r{Perl-Apache( PMC)?}, 'Perl'
  title.sub! %r{Portable Runtime$}, 'Portable Runtime (APR)'
  title.sub! %r{Public Relations Committee}, 'Public Relations'
  title.sub! %r{Security$}, 'Security Team'
end

# Dir.chdir(SVN_SITE_RECORDS_MINUTES) { system 'svn update' }

agenda = {}

posted = Dir[MINUTES_PATH].sort
unapproved = Dir[File.join(BOARD, MINUTES_NAME)].sort

FileUtils.mkdir_p SITE_MINUTES

seen={}

(posted+unapproved).each do |txt|
  date = $1 if txt =~ /(\d\d\d\d_\d\d_\d\d)/
  next unless date
  if seen.has_key? date
    Wunderbar.warn "Already processed #{seen[date]}; skipping #{txt}"
    next
  end
  seen[date] = txt
  minutes = open(txt) {|file| file.read}
  pending = {}

  # parse Attachments (includes both Officer Reports and Committee Reports)
  minutes.scan(/
    -{41}\n                        # separator
    Attachment\s\s?(\w+):[ ](.+?)\n # Attachment, Title
    (.)(.*?)\n                     # separator, report
    (?=-{41,}\n(?:End|Attach))     # separator
  /mx).each do |attach,title,cont,text|

    # We need to keep the start of the second line.
    # Otherwise leading spaces in the report body look like a continuation line
    if cont == ' ' # continuation line was not empty; check if it's a continuation
      # join multiline titles
      while text.start_with? '        '
        append, text = text.split("\n", 2)
        title += ' ' + append.strip
      end
    end

    title.sub! /Special /, ''
    title.sub! /Requested /, ''
    title.sub! /(^| )Report To The Board( On)?( |$)/i, ''
    title.sub! /^Board Report for /, ''
    title.sub! /^Status [Rr]eport for (the )?/, ''
    title.sub! /^Report from the VP of /, ''
    title.sub! /^Report from the /i, ''
    title.sub! /^Status report for the /i, ''
    title.sub! /^Apache /, ''
    title.sub! /^\/ /, ''
    title.sub! /\s+\[.*\]\s*$/, ''
    title.sub! /\sTeam$/, ''
    title.sub! /\s[Cc]ommittee?\s*$/, ''
    title.sub! /\s[Pp]roject\s*$/, ''
    title.sub! /\sPMC$/, ''
    title.sub! 'Apache Software Foundation', 'ASF'

    name_changes(title)

    next if title.strip.empty?
    next if text.strip.empty? and title =~ /Intentionally (left )?Blank/i
    next if text.strip.empty? and title =~ /There is No/i

    report = pending[attach] || OpenStruct.new
    report.meeting = date
    report.attach = attach
    report.title = title.strip #.downcase
    report.text = text

    if title =~ /budget|spending/i
      report.subtitle = title
      report.title = 'Budget'
      report.attach = '@' + attach
    elsif title =~ /Contributor License Agreement/
      report.subtitle = title
      report.title = 'Legal Affairs'
      report.attach = '1' + attach
    elsif title =~ /P(rofit-and-|&)L(oss)? Report/
      report.subtitle = title
      report.title = 'Treasurer'
      report.attach = '1' + attach
    elsif title =~ /alleged JBoss IP infringement/
      report.subtitle = title
      report.title = 'Alleged JBoss IP Infringement'
      report.attach = '@' + attach
    elsif title =~ /Written Consent of the Directors/
      report.attach = '@' + attach
    end

    pending[attach] = report

    if title == 'Incubator' and text
      sections = text.split(/\nStatus [rR]eport (.*)\n=+\n/)
      # Some minutes have a 'Detailed Reports' header before the first podling report
      # podling header may now be prefixed with ## (since June 2019)
      # Also there may be a blank line before the ##
      sections = text.split(/\n[-=][-=]+(?: Detailed Reports ---+)?\n(?:\n?##)?\s*([a-zA-Z].*)\n\n/) if sections.length < 9
      sections = [''] if sections.include? 'FAILED TO REPORT'
      sections = text.split(/\n(\w+)\n-+\n\n/) if sections.length < 9
      sections = text.split(/\n=+\s+([\w.]+)\s+=+\n+/) if sections.length < 9

      prev = nil

      if sections.length > 1
        report.text = sections.shift
        sections.each_slice(2) do |title, text|
          title.sub! /^regarding /, ''
          title.sub! /^for /, ''
          title.sub! /^from /, ''
          title.sub! /^the /, ''
          title.sub! /\sPPMC$/, ''

          if title =~ /Apache (.*) is a/
            text = title + "\n" + text
            title = $1
          end

          if title =~ /(.*) has been incubating/
            text = title + "\n" + text
            title = $1
          end

          if title =~ /(.*) -- (DID NOT REPORT)/
            text = $2 + "\n" + text
            title = $1
          end

          if title =~ /(.*?) - (.*)/
            text = $2 + "\n" + text
            title = $1
          end

          if title =~ /(.*? sponsored) incubation \((.*)\)/
            text = $2 + "\n" + text
            title = $1
          end

          next if title == 'April 2011 podling reports'

          name_changes(title)

          title.sub! /\s+\(.*\)$/, ''
          title.sub! /^Apache(: Project)?/, ''

          if %w(Mentors Committers).include? title
            prev.text += "\n== #{title}==\n\n#{text}" if prev
            next
          end

          report = OpenStruct.new
          report.meeting = date
          report.attach = '.' + title
          report.title = title.strip
          report.text = text
          pending[report.attach] = report

          prev = report
        end
      end
    end
  end

  # parse Officer and Committee Reports for owners and comments
  minutes.scan(/
    \[([^\n]+)\]\n\n                  # owners
    \s{7}See\sAttachment\s\s?(\w+)    # attach
    (.*?)\n                           # comments
    \s\s\s\s?\w                       # separator
  /mx).each do |owners,attach,comments|
    report = pending[attach] || OpenStruct.new
    report.meeting = date
    report.attach = attach
    report.owners = owners
    report.comments = comments.strip
    pending[attach] = report
  end

  # fill in comments from missing reports
  ['Committee', 'Additional Officer'].each do |section|
    reports = minutes[/^ \d\. #{section} Reports(\s*(\n|  .*\n)+)/,1]
    next unless reports
    reports.split(/^    (\w+)\./)[1..-1].each_slice(2) do |attach, comments|
      next if attach.length > 2
      owners = comments[/\[([^\n]+)\]/,1]
      next if comments.include? 'See Attachment'
      comments.sub! /.*\s+\n/, ''
      next if comments.empty?
      attach = ('A'..attach).count.to_s if section == 'Additional Officer'

      report = pending[attach] || OpenStruct.new
      report.meeting = date
      report.attach = attach
      report.owners = owners
      report.comments = comments.strip
      pending[attach] = report
    end
  end

  # parse Action Items
  minutes.scan(/
    \n\s+(\w+)\.\s                    # attach
    Review\sOutstanding\s(Action\sItems)\n\n?
    (.*?)                             # text
    \n\s?\d                           # separator
  /mx).each do |attach, title, text|
    report = OpenStruct.new
    report.title ||= title #.downcase
    report.meeting = date
    report.attach = '+' + title
    text.gsub! /^\s?\d+\.\s.*\s*\Z/, ''
    report.text = text.gsub Regexp.new('^'+text.match(/^ */)[0]), '' if text
    pending[title] = report
  end

  # parse other agenda items
  establish='' # pick up misplaced PMC creates
  minutes.scan(/
    \n\s*(\w+)\.\s                    # attach
    (Discussion\sItems|Unfinished\sBusiness|New\sBusiness|Announcements)\n
    (.*?)                             # text
    (?=\n\s?\d)                       # separator
  /mx).each do |attach, title, text|
    next if text.strip.empty?
    next if text =~ /\A\s*none\.?\s*\z/i
    next if text =~ /\A\s*no unfinished business\.?\s*\z/i
    if text =~ /Establish the Apache \S+ Project/ # 2012_08_28
      establish += text
      next
    end

    if title !~ /Discussion/ or text !~ /\A\n*\s{3,5}[0-9A-Z]\.\s.*\n\n/
      report = OpenStruct.new
      report.title ||= title #.downcase
      report.meeting = date
      report.attach = '+' + title
      report.text = text.strip
      pending[title] = report
    else
      text.scan(/
        \s{3}[\s\d]([0-9A-Z])\. # agenda item
        \s+(.*?)\n              # title
        (.*?)                   # text
        (?=\n\s{3,5}\d?[0-9A-Z]\.\s|\z) # next section
      /mx).each do |attach,title,text|
        if title.include? "\n" and title.length > 120
          title = title.split("\n")
          text = title[1..-1].join("\n") + "\n" + text
          title = title[0]
        end

        title.sub! 'VP, Data Privacy', 'VP Data Privacy'

        report = OpenStruct.new
        report.title = title.gsub(/\s+/, ' ')
        report.meeting = date
        report.attach = '+' + title
        report.text = text.strip

        if title =~ /budget|spending/i
          report.subtitle = title
          report.title = 'Budget'
          report.attach = '@' + attach
        elsif title =~ /Legal Affairs/
          report.subtitle = title
          report.title = 'Legal Affairs'
          report.attach = '1' + attach
        elsif title =~ /date.+member.+meeting/i || title =~ /member.+meeting.+date/i
          report.subtitle = title
          report.title = 'Set Date for Members Meeting'
          report.attach = '@' + attach
        else
          pmcs = %w{Geronimo iBATIS Santuario}
          pmcs.each do |pmc|
            if title =~ /#{pmc}/i
              report.subtitle = title
              report.title = pmc
              report.attach = '.' + pmc
            end
          end
        end

        pending[title] = report
      end
    end
  end

  # parse Special Orders
  orders = establish + minutes.split(/^ \d\. Special Orders/,2).last.split(/^ \d\./,2).first
  # Some section ids have a leading digit, hence [\s\d]
  orders.scan(/
    \s{3}[\s\d]([A-Z])\.    # agenda item
    \s+(.*?)\n\s*\n         # title
    (.*?)                   # text
    (?=\n\s{3,4}[\s\d][A-Z]\.\s|\z) # next section
  /mx).each do |attach,title,text|
    next if title.count("\n")>1
    report = OpenStruct.new
    title.sub! /(^|\n)\s*Resolution R\d:/, ''
    title.sub!(/^(?:Proposed )?Resolution (\[R\d\]|to|for) ./) {|c| c[-1..-1].upcase}
    title.sub! /\.$/, ''
    report.title ||= title.strip
    report.meeting = date
    report.attach = '@' + title
    report.text = text.strip

    # Columns:
    # Pfx Title Match
    # If Title is a number, then extract that part of the match
    rules = [
      :X, 2, /Terminat(e|ion of) the (.+?) (Project|PMC|Committee)/,
      :X, 1, /Separate (.+?) from the Apache Software Foundation/,

      :E, 1, /Establishing a PMC for a (.*) project/,
      :E, 1, /Establish (.+?) as a top level project/,
      :E, 1, /Establish (AsterixDB)/, # 2016_04_20
      :E, 4, /Estab?lish(ing|ment)? (of )?(the |an )?(.+?) (board )?(PMC|[pP]roject|[cC]ommittee)$/,
      :E, 2, /Creat(e|ion of) the (.+?) (Project|PMC)/,
      :E, 2, /To (re-establish|create) the (.+?) PMC/,
      :E, 2, /Reestablish(ing the)? (.+?)( Project| Committee | Team)/,
      :E, 1, /^Apache (.+?) Project$/,


      :C, 3, /(Change|Appoint).* Vice President of (the )?(.+)/,
      :C, 2, /(Appoint|Establish) a new (.+?) PMC Chair/,
      :C, 1, /New Vice President for the (.+?) PMC/,
      :C, 1, /Appoint.* as the (.*?) of the ASF/,
      :C, 1, /Appointment of (.*?) Committee Chair/,
      :C, 3, /Appoint(ing a)? new [cC]hair (for|of the) (.*?)( Project|$)/,
      :C, 1, /Alter the Chair of the (.+?) Project/,
      :C, 2, /[cC]hange (the )?[cC]hair of the (.+?) (Project|PMC)/,
      :C, 3, /[Cc]hang(e|ing) (to )?the (.+?) (Project |PMC )?Chair/,
      :C, 2, /Change (of|the) (.+?) (PMC |Project |Committee )Chair/,
      :C, 1, /Resolution to change the (.+?) Chair/,
      :C, 1, /PMC chair change for (.+)/,
      :C, 1, /Change PMC [Cc]hair for (.+?) Project/,
      :C, 3, /Appoint a (new )?(chair for |Vice President of )(.+)/,
      :C, 1, /Appoint .*? as (.+?) chairman/,
      :C, 1, /Change Chair for Apache (.+)/,

      :M, 1, /Reboot the (.+?) (PMC|Committee)/,
      :M, 1, /(.+?) election of new PMC/,
      :M, 2, /Update (membership of the )?(.+?) Committee/,
      :M, 1, /Change to the (.*)? Committee Membership/,
      :M, 1, /Change the Apache (.*) Project Name/,
      :M, 1, /Change the Apache (.*) Project Management Committee/,
       1, 1, /Update ?(audit.+?) Membership/i,
      :M, 1, /Update ?(.+?) Membership/,
      :R, 1, /Rename.* to the ?(.+?) Project/,

      '@', 1, /(.*) Renewal/,

      :C, 'Conference Planning', /Conferences? Committee/,

      '@', 'Budget', /Spending Resolution/i,
      '@', 'Budget', /Budget/i,
      '@', 'Bylaws', /Bylaw/i,
      '@', 'Chief Media Officer', /Chief Media Officer/i,

      1, 'JCP', /Java Community Process/,
      1, 'JCP', /JCP/,
      1, 'Public Relations', /Public Relations/i,
      1, 'Marketing and Publicity', /Press/i,
      1, 'Legal Affairs', /License/i,
      1, 'Legal Affairs', /Copyright/i,
      1, 'Legal Affairs', /contributor agreement/i,
      1, 'Legal Affairs', /CLA/,
      1, 'Legal Affairs', /[MG]PL/,
      1, 'Brand Management', /use.*feather/,
      1, 'Brand Management', /Trademark/,
      1, 'Brand Management', /use.*Apache name/,
      1, 'Brand Management', /Brand Management/i,
      1, 'Travel Assistance', /TAC/,
      1, 'Travel Assistance', /Travel Assistance/,
      1, 'Conference Planning', /Conference Planning/,
      1, 'Fundraising', /Fundraising/,
      1, 'Audit', /Audit/i,

      :C, 'Public Relations', /Appoint Brian Fitzpatrick as a Vice President/,

      '@', 'Appoint Executive Officers', /Appoint(ment of)? (new |ASF )?[oO]fficers/,
      '@', 'Appoint Executive Officers', /Election of Officers/,
      '@', 'Appoint Executive Officers', /Officer Appointments/i,
      '@', 'Set Date for Members Meeting', /date.* member'?s meeting/i,
      '@', 'PMC Membership Change Process', /Empower PMC chairs to change the membership/i,
      '@', 'PMC Membership Change Process', /Amend the Procedure for PMC Membership Changes/i,
      '@', 'Secretarial Assistant', /Approve contract with Jon Jagielski/,
      '@', 'Alleged JBoss IP Infringement', /alleged JBoss IP infringe?ment/,
      '@', 'Discussion Items', /^Discuss/
    ]

    rules.each_slice(3) do |prefix, select, pattern|
      match = pattern.match(report.title)
      if match
        report.subtitle = report.title
        if select.is_a? Integer
          report.title = match[select]
        else
          report.title = select
        end
        report.attach = "#{prefix}#{report.attach}"
        break
      end
    end

    report.title.sub! /^Apache /, ''

    name_changes(report.title)

    report.title.sub! 'standing Audit', 'Audit'
    report.title.sub! 'federated identity', 'Federated Identity'
    report.title.sub! 'WSIF', 'Web Services'

    pending[title] = report
  end

  # parse (Executive) Officer Reports
  execs = minutes[/Officer Reports(.*?)\n[[:blank:]]{1,3}\d+\./m,1]
  if execs
    execs.sub! /\s*Executive officer reports approved.*?\n*\Z/, ''
    # attachments start like this:
    att_prefix = '\n[[:blank:]]{1,5}([A-Z])\.[[:blank:]]'
    execs.scan(/
      #{att_prefix}([^\n]*?)\n          # attach, title
      (.*?)                             # text
      (?=#{att_prefix}|\Z)              # separator
    /mx).each do |attach, title, text|
      next unless text
      next unless title
      next if title.start_with? 'This interim budget shows a surplus'
      next if title.start_with? "President's discretionary fund returned to"

      title.sub! 'Executive VP', 'Executive Vice President'
      title.sub! 'Exec. V.P. and Secretary', 'Secretary'
      title.sub! 'Vice Chairman', 'Vice Chair'
      title.sub! 'Acting Chairman', 'Acting Chair'
      title.sub! 'Chairman', 'Board Chair'

      report = OpenStruct.new
      if title.include? ' ['
        report.owners = title.split(' [').last.sub(']','').strip
        title = title.split(' [').first
      end
      report.title ||= title.strip #.downcase
      report.title.gsub! /^V\.?P\.? of /, ''
      report.title.gsub! /\/Apache$/, ''
      report.title = 'Infrastructure' if report.title =~ /Infrastructure/
      report.title = 'Treasurer' if report.title =~ /Treasurer/
      report.meeting = date
      report.attach = '*' + title
      report.text = text.dup
      pending[title] = report
    end
  end

  # Add to the running tally
  pending.each_value do |report|
    next if not report.title or report.title.empty?

    # flag unposted reports; exclude unposted special orders
    report.posted = posted.include? txt
    next if not report.posted and
      (report.attach =~ /^[A-Z]?@/ or report.attach !~ /^[A-Z.]/)

    agenda[report.title] ||= []
    agenda[report.title] << report
  end
end

puts

# determine link for each report
link = {}
agenda.each do |title, reports|
  link[title] = title.sub('C++','Cxx').gsub(/\W/,'_') + '.html'
end

# Simplify creating content
def getHTMLbody()
  builder = Builder::XmlMarkup.new :indent => 2
  yield builder
  return Nokogiri::HTML(builder.target!).at('body').children
end

# Combine content produced here with the template fetched previously
def layout(title = nil)
  builder = Builder::XmlMarkup.new :indent => 2
  yield builder
  content = Nokogiri::HTML(builder.target!)
  if title
    $calendar.at('title').content = "Board Meeting Minutes - #{title}"
#   $calendar.at('h2').content = "Board Meeting Minutes - #{title}"
  else
    $calendar.at('title').content = "Board Meeting Minutes"
#   $calendar.at('h2').content = "Board Meeting Minutes"
  end

  # Adjust the page header

  # find the intro para; assume it is the first para with a strong tag
  # then back up to the main container class for the page content
  section = $calendar.at('.container p strong').parent.parent
  # Extract all the paragraphs
  paragraphs = section.search('p')

  # remove all the existing content
  section.children.each {|child| child.remove}

  # Add the replacement first para
  section.add_child getHTMLbody {|x|
    x.p do
      if title
        x.text! "This was extracted (@ #{STAMP}) from a list of"
      else # main index, which is always replaced if any input files have changed
        # text below must agree with code that updates the index when no changes have occurred
        x.text! "Last run: #{STAMP}. The data is extracted from a list of"
      end
      x.a 'minutes', :href => 'http://www.apache.org/foundation/records/minutes/'
      x.text! "which have been approved by the Board."
      x.br
      x.strong 'Please Note'
      # squiggly heredoc causes problems for Eclipse plugin, but leading spaces don't matter here
      x.text! <<-EOT
      The Board typically approves the minutes of the previous meeting at the
      beginning of every Board meeting; therefore, the list below does not
      normally contain details from the minutes of the most recent Board meeting.
      EOT
    end
  }

  # and the second para which is assumed to be the list of years
  section.add_child paragraphs[1]
  section.add_child "\n" # separator to make it easier to read source

  # now add the content provided by the builder block
  content.at('body').children.each {|child| section.add_child child}

  $calendar.to_html
end

Dir.entries(SITE_MINUTES).each do |p|
  next unless p.end_with? '.html'
  next if p == 'index.html'
  unless link.has_value? p
    unless KEEP
      Wunderbar.info "Dropping #{p}"
      File.delete(File.join(SITE_MINUTES,p))
    else
      Wunderbar.info "Outdated? #{p}"
    end
  end
end

# remove variable date from page
def remove_date(page)
  # '%Y-%m-%d %H:%M'
  page.sub /This was extracted \(@ \d\d\d\d-\d\d-\d\d \d\d:\d\d\) from a list of/,''
end

# output each individual report by owner
agenda.sort.each do |title, reports|
  page = layout(title) do |x|
    info = site[canonical[title.downcase]]
    if info
      # site information found, link to it
      x.h1 do
        x.a info[:name], :href => info[:link], :title => info[:text]
      end
    else
      x.h1 title
    end
    reports.reverse.each do |report|
      _id = report.meeting.gsub('_', '-')
      x.h2 id: _id do
        if report.posted
          href = "http://apache.org/foundation/records/minutes/" +
            "#{report.meeting[0...4]}/board_minutes_#{report.meeting}.txt"
        else
          href = ASF::SVN.svnpath!('foundation_board', "board_minutes_#{report.meeting}.txt")
        end

        x.a Date.parse(report.meeting.gsub('_','/')).strftime("%d %b %Y"),
          href: href, id: "minutes_#{report.meeting}"
        if report.owners
          x.span "[#{report.owners}]", :style => 'font-size: 14px'
        end
        # Add headerlink marker
        x.a '¶', href: "##{_id}", title: 'Permanent link', :class => 'headerlink'
      end
      x.h3 report.subtitle if report.subtitle

      if report.posted
        text = report.text.gsub(/^\t+/) {|tabs| " " * (8*tabs.length)}
        text.gsub!(/ *$/, "")
        indent = text.scan(/^([ ]+)/).flatten.min.to_s.length - 1
        text.gsub! /^#{' '*indent}/, '' if indent > 0
        text = $1 + text if text =~ /\A\w.*\n(\s+)/
        text = text.to_s.rstrip
        # N.B. The syntax "class: report" causes problems for the Eclipse Ruby plugin
        x.pre text, 'class' => 'report' unless text.strip.empty?

        if report.comments and report.comments.strip != ''
          report.comments.split(/\n\s*\n/).each do |p|
            x.p p, :style => "width: 40em"
          end
        elsif text.strip.empty?
          if report.subtitle and not report.subtitle.empty?
            x.p {x.em 'Discussion Item with no text or minutes'}
          else
            x.p {x.em 'A report was expected, but not received'}
          end
        end
      elsif report.text.strip.empty?
        x.p {x.em 'A report was expected, but not received'}
      else
        x.p do
          x.em 'Report was filed, but display is awaiting the approval ' +
            'of the Board minutes.'
        end
      end
    end
  end

  dest = File.join(SITE_MINUTES, link[title])
  unless File.exist?(dest) and remove_date(File.read(dest)) == remove_date(page)
    Wunderbar.info  "Writing #{link[title]}"
    open(dest, 'w') {|file| file.write page}
#  else
#    Wunderbar.info  "Not updating #{link[title]}"
  end
end

if DUMP_AGENDA
  agenda.each do |title, reports|
    p [reports.length > 1 ? '>1' : '=1', reports.last.attach[0..1], reports.length, title]
  end
end

# Classification scheme
# Pfx = reports.last.attach[0]
# Count = reports.length
#
# Pfx    Count     Section
# '*'     >1       Executive Officer Reports
# 0-9     >1       Additional Officer Reports
# A-Z     >1       Committee Reports
# '.'     any      Podling Reports
# '@'     >1       Repeating Special Orders
# '+'     >1       Other Agenda Items
# !'.'    =1       Other Attachments, Special Orders, and Discussions

# output index
agenda = agenda.sort_by {|title, reports| title.downcase}
page = layout do |x|
  x.h2 "Executive Officer Reports", :id => 'executive'
  x.ul do
    agenda.each do |title, reports|
      next unless reports.last.attach =~ /^\*/
      next if reports.length == 1
      x.li do
        x.a title, :href => link[title]
      end
    end
  end
  x.h2 "Additional Officer Reports", :id => 'officer'
  x.ul do
    agenda.each do |title, reports|
      next unless reports.last.attach =~ /^\d/
      next if reports.length == 1
      x.li do
        x.a title, :href => link[title]
      end
    end
  end
  x.h2 "Committee Reports", :id => 'committee'
  list = []
  agenda.each do |title, reports|
    next unless reports.last.attach =~ /^[A-Z]/
    next if reports.length == 1
    list << title
  end
  cols = 6
  slice = (list.length+cols-1)/cols
  x.table do
    (0...slice).each do |i|
      x.tr do
        (0...cols).each do |j|
          x.td do
            title = list[i+j*slice]
            if title
              info = site[canonical[title.downcase]]
              if info
                x.a title, :href => link[title], :title => info[:text]
              else
                if cinfo['committees'][title]
                  x.em { x.a title, :href => link[title] }
                else
                  x.del { x.a title, :href => link[title] }
                end
              end
            end
          end
        end
      end
    end
  end
  x.h2 "Podling Reports", :id => 'podling'
  list = []
  agenda.each do |title, reports|
    next unless reports.last.attach =~ /^[.]/
    list << title
  end
  cols = 6
  slice = (list.length+cols-1)/cols
  x.table do
    (0...slice).each do |i|
      x.tr do
        (0...cols).each do |j|
          x.td do
            title = list[i+j*slice]
            if title
              info = site[canonical[title.downcase]]
              if info
                if %w{dormant retired}.include? info[:status]
                  x.del do
                    x.a title, :href => link[title], :title => info[:text]
                  end
                else
                  x.a title, :href => link[title], :title => info[:text]
                end
              else
                x.em { x.a title, :href => link[title] }
              end
            end
          end
        end
      end
    end
  end
  x.h2 "Repeating Special Orders", :id => 'orders'
  x.ul do
    agenda.each do |title, reports|
      next unless reports.last.attach =~ /^@/
      next if reports.length == 1
      x.li do
        x.a title, :href => link[title]
      end
    end
  end
  x.h2 "Other Attachments, Special Orders, and Discussions", :id => 'other'
  x.ul do
    other = {}
    agenda.each do |title, reports|
      next unless reports.length == 1
      next if reports.last.attach =~ /^[.]/
      other[reports.first.subtitle || title] = title
    end
    other.sort.each do |subtitle, title|
      x.li do
        x.a subtitle, :href => link[title]
      end
    end
  end
  x.h2 "Other Agenda Items", :id => 'agenda'
  x.ul do
    agenda.each do |title, reports|
      next unless reports.last.attach =~ /^\+/
      next if reports.length == 1
      x.li do
        x.a title, :href => link[title]
      end
    end
  end
end

open(INDEX_FILE, 'w') {|file| file.write page}

Wunderbar.info "Wrote #{SITE_MINUTES}/index.html"
