#!/usr/bin/env ruby
PAGETITLE = "Board@ Mailing List Statistics" # Wvisible:board
$LOAD_PATH.unshift '/srv/whimsy/lib'

require 'wunderbar'
require 'wunderbar/bootstrap'
require 'wunderbar/jquery'
require 'whimsy/asf'
require 'whimsy/asf/agenda'
require 'date'
require 'mail'

SRV_MAIL = '/srv/mail/board'
DATE = 'date'
FROM = 'from'
WHO = 'who'
SUBJECT = 'subject'
COMMITTER = 'committer'
TOOLS = 'tools'
MAILS = 'mails'

### ---- Copied from tools/mboxhdr2csv.rb; should be refactored ----
MEMBER = 'member'
COMMITTER = 'committer'
COUNSEL = 'counsel'
# Subject regexes that are non-discussion oriented for flagging
NONDISCUSSION_SUBJECTS = { # Note: none applicable to members@
  '<board.apache.org>' => {
    missing: /\AMissing\s((\S+\s){1,3})Board/, # whimsy/www/board/agenda/views/buttons/email.js.rb
    feedback: /\ABoard\sfeedback\son\s20/, # whimsy/www/board/agenda/views/actions/feedback.json.rb
    notice: /\A\[NOTICE\]/i,
    report: /\A\[REPORT\]/i,
    resolution: /\A\[RESOLUTION\]/i,
    svn_agenda: %r{\Aboard: r\d{4,8} - /foundation/board/},
    svn_iclas: %r{\Aboard: r\d{4,8} - /foundation/officers/iclas.txt}
  }
}
# Annotate mailhash by adding :who and COMMITTER (where known)
# @param email address to check
# @returns ['Full Name', 'committer-flag'
# COMMITTER = 'n' if not found; 'N' if error, 'counsel' for special case
def find_who_from(email)
  # Remove bogus INVALID before doing lookups
  from = email.sub('.INVALID', '')
  who = nil
  committer = nil
  # Micro-optimize unique names
  case from
  when /Mark.Radcliffe/i
    who = 'Mark.Radcliffe'
    committer = COUNSEL
  when /mattmann/i
    who = 'Chris Mattmann'
    committer = MEMBER
  when /jagielski/i
    who = 'Jim Jagielski'
    committer = MEMBER
  when /delacretaz/i
    who = 'Bertrand Delacretaz'
    committer = MEMBER
  when /curcuru/i
    who = 'Shane Curcuru'
    committer = MEMBER
  when /steitz/i
    who = 'Phil Steitz'
    committer = MEMBER
  when /gardler/i  # Effectively unique (see: Heidi)
    who = 'Ross Gardler'
    committer = MEMBER
  when /Craig (L )?Russell/i # Optimize since Secretary sends a lot of mail
    who = 'Craig L Russell'
    committer = MEMBER
  when /McGrail/i
    who = 'Kevin A. McGrail'
    committer = MEMBER
  when /khudairi/i 
    who = 'Sally Khudairi'
    committer = MEMBER
  else
    begin
      # TODO use Real Name (JIRA) to attempt to lookup some notifications
      tmp = liberal_email_parser(from)
      person = ASF::Person.find_by_email(tmp.address.dup)
      if person
        who = person.cn
        if person.asf_member?
          committer = MEMBER
        else
          committer = COMMITTER
        end
      else
        who = "#{tmp.display_name} <#{tmp.address}>"
        committer = 'n'
      end
    rescue
      who = from # Use original value here
      committer = 'N'
    end
  end
  return who, committer
end

# @see www/secretary/workbench/models/message.rb
# @see https://github.com/mikel/mail/issues/39
def liberal_email_parser(addr)
  begin
    addr = Mail::Address.new(addr)
  rescue
    if addr =~ /^"([^"]*)" <(.*)>$/
      addr = Mail::Address.new
      addr.address = $2
      addr.display_name = $1
    elsif addr =~ /^([^"]*) <(.*)>$/
      addr = Mail::Address.new
      addr.address = $2
      addr.display_name = $1
    else
      raise
    end
  end
  return addr
end
### ---- Copied from tools/mboxhdr2csv.rb; should be refactored ----

# Get {MAILS: [{date, who, subject, flag},...\, TOOLS: [{...},...] } from the specified list for a month
# May cache data in SRV_MAIL/yearmonth.json
def get_mails_month(yearmonth:, nondiscuss:)
  # Return cached calculated data if present
  cache_json = File.join(SRV_MAIL, "#{yearmonth}.json")
  if File.exist?(cache_json)
    return JSON.parse(File.read(cache_json))
  else
    files = Dir[File.join(SRV_MAIL, yearmonth, '*')]
    emails = {}
    emails[MAILS] = []
    emails[TOOLS] = []
    files.each do |email|
      next if email.end_with? '/index'
      message = IO.read(email.untaint, mode: 'rb')
      data = {}
      data[DATE] = DateTime.parse(message[/^Date: (.*)/, 1]).iso8601
      data[FROM] = message[/^From: (.*)/, 1]
      data[WHO], data[COMMITTER] = find_who_from(data[FROM])
      data[SUBJECT] = message[/^Subject: (.*)/, 1]
      if nondiscuss
        nondiscuss.each do |typ, rx|
          if data[SUBJECT] =~ rx
            data[TOOLS] = typ
            break # regex.each
          end
        end
      end
      data.has_key?(TOOLS) ? emails[TOOLS] << data : emails[MAILS] << data
    end
    # Provide as sorted data for ease of use
    emails[TOOLS].sort_by! { |email| email[DATE] }
    emails['toolcount'] = Hash.new {|h, k| h[k] = 0 }
    emails[TOOLS].each do |mail|
      emails['toolcount'][mail[TOOLS]] += 1
    end
    emails['toolcount'] = emails['toolcount'].sort_by { |k,v| -v}.to_h
    
    emails[MAILS].sort_by! { |email| email[DATE] }
    emails['mailcount'] = Hash.new {|h, k| h[k] = 0 }
    emails[MAILS].each do |mail|
      emails['mailcount'][mail[WHO]] += 1
    end
    emails['mailcount'] = emails['mailcount'].sort_by { |k,v| -v}.to_h

    # If yearmonth is before current month, then write out yearmonth.json as cache
    if yearmonth < Date.today.strftime('%Y%m')
      begin
        File.open(cache_json, 'w') do |f|
          f.puts JSON.pretty_generate(emails)
        end
      rescue
        # No-op, just don't cache for now
      end
    end
    return emails
  end
end

# produce HTML
_html do
  _body? do
    _whimsy_body(
      title: PAGETITLE,
      related: {
        "/board/agenda" => "Current Month Board Agenda",
        "/board/minutes" => "Past Minutes, Categorized",
        "https://www.apache.org/foundation/board/calendar.html" => "Past Minutes, Dated",
        "https://github.com/apache/whimsy/blob/master/www#{ENV['SCRIPT_NAME']}" => "See This Source Code"
      },
      helpblock: -> {
        _p %{
          This script displays some simple (and potentially lossy) analysis of traffic on the board@ mailing list.
          In particular, mapping email to a committer may not work (meaning individual senders may have multiple spots),
          and Subject lines displayed may be truncated (meaning threads may not fully be tracked).  Work in progress.
          Attempts to differentiate tool- or process-generated emails (NOTICE, REPORT, etc.) from all other emails.
        }
      }
    ) do
      months = %w(201901 201902 201903 201904 201905) # HACK figure out what we want to track / make interactive
      months.each do |month|
        data = get_mails_month(yearmonth: month, nondiscuss: NONDISCUSSION_SUBJECTS['<board.apache.org>'])
        _h1 "Top Ten Email Senders to board@ (by mails) #{month}"
        _ul? do
          ctr = 0
          data['mailcount'].each do |id, num|
            _li "#{id} wrote: #{num}"
            ctr += 1
            break if ctr >= 10
          end
        end
        _h1 "Tool Generated Mails to board@ (by type) #{month}"
        _ul? do
          data['toolcount'].each do |id, num|
            _li "#{num} emails from #{id} tool"
          end
        end
      end
    end
  end
end
