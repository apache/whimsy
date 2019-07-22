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
require '../../tools/mboxhdr2csv.rb'

user = ASF::Person.new($USER)
unless user.asf_member? or ASF.pmc_chairs.include? user
  print "Status: 401 Unauthorized\r\n"
  print "WWW-Authenticate: Basic realm=\"ASF Members and Officers\"\r\n\r\n"
  exit
end

SRV_MAIL = '/srv/mail/board'
DATE = 'date'
FROM = 'from'
WHO = 'who'
SUBJECT = 'subject'
TOOLS = 'tools'
MAILS = 'mails'
TOOLCOUNT = 'toolcount'
MAILCOUNT = 'mailcount'
WEEK_TOTAL = '@@total' # Use @@ so it can't match who name/emails
WEEK_START = '@@start'

# Get {MAILS: [{date, who, subject, flag},...\, TOOLS: [{...},...] } from the specified list for a month
# May cache data in SRV_MAIL/yearmonth.json
# Returns empty hash if error or if can't find month
def get_mails_month(yearmonth:, nondiscuss:)
  # Return cached calculated data if present
  cache_json = File.join(SRV_MAIL, "#{yearmonth}.json")
  if File.file?(cache_json)
    return JSON.parse(File.read(cache_json))
  else
    emails = {}
    files = Dir[File.join(SRV_MAIL, yearmonth, '*')]
    return emails if files.empty?
    emails[MAILS] = []
    emails[TOOLS] = []
    files.each do |email|
      next if email.end_with? '/index'
      message = IO.read(email.untaint, mode: 'rb')
      data = {}
      data[DATE] = DateTime.parse(message[/^Date: (.*)/, 1]).iso8601
      data[FROM] = message[/^From: (.*)/, 1]
      data[WHO], data[MailUtils::COMMITTER] = MailUtils.find_who_from(data)
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
    emails[TOOLCOUNT] = Hash.new {|h, k| h[k] = 0 }
    emails[TOOLS].each do |mail|
      emails[TOOLCOUNT][mail[TOOLS]] += 1
    end
    emails[TOOLCOUNT] = emails[TOOLCOUNT].sort_by { |k,v| -v}.to_h
    
    emails[MAILS].sort_by! { |email| email[DATE] }
    emails[MAILCOUNT] = Hash.new {|h, k| h[k] = 0 }
    emails[MAILS].each do |mail|
      emails[MAILCOUNT][mail[WHO]] += 1
    end
    emails[MAILCOUNT] = emails[MAILCOUNT].sort_by { |k,v| -v}.to_h

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

# Display monthly statistics for all available data
def display_monthly(months:, nondiscuss:)
  months.sort.reverse.each do |month|
    data = get_mails_month(yearmonth: month, nondiscuss: nondiscuss)
    next if data.empty?
    _h1 "board@ statistics for #{month} (total mails: #{data[MAILS].length + data[TOOLS].length})", id: "#{month}"
    _div.row do
      _div.col_sm_6 do
        _ul.list_group do
          _li.list_group_item.active.list_group_item_info "Top Ten Email Senders (from non-tool mails: #{data[MAILS].length})"
          ctr = 0
          data[MAILCOUNT].each do |id, num|
            if num > (data[MAILS].length / 10)
              _li.list_group_item.list_group_item_warning "#{id} wrote: #{num}"
            else
              _li.list_group_item "#{id} wrote: #{num}"
            end
            ctr += 1
            break if ctr >= 10
          end
        end   
      end
      _div.col_sm_6 do
        _ul.list_group do
          _li.list_group_item.list_group_item_info "Tool Generated Emails (by type, total tool mails: #{data[TOOLS].length})"
          data[TOOLCOUNT].each do |id, num|
            _li.list_group_item "#{num} emails from #{id} tool"
          end
        end
      end
    end
  end
end

# Display weekly statistics for non-tool emails
def display_weekly(months:, nondiscuss:)
  weeks = Hash.new {|h, k| h[k] = {}}
  months.sort.each do |month|
    data = get_mails_month(yearmonth: month, nondiscuss: nondiscuss)
    next if data.empty?
    # accumulate all mails in order for weeks, through all months
    data[MAILS].each do |m|
      d = Date.parse(m['date'])
      wn = d.strftime('%G-W%V')
      if weeks.has_key?(wn)
        weeks[wn][m['who']] +=1
      else
        weeks[wn] = Hash.new{ 0 }
        weeks[wn][m['who']] = 1
      end
    end
  end
  _h1 "board@ list non-tool emails weekly statistics", id: "top"
  _div.row do
    _div.col.col_sm_offset_1.col_sm_9 do
      weeks.each do |week, senders|
        total = 0
        senders.each do |sender, count|
          next if /@@/ =~ sender
          total += count
        end
        senders[WEEK_TOTAL] = total
        _ul.list_group do
          _li.list_group_item.active.list_group_item_info "Week #{week} Top Senders (total mails: #{senders[WEEK_TOTAL]})", id: "#{week}"
          ctr = 0
          senders.sort_by {|k,v| -v}.to_h.each do |id, num|
            next if /@@/ =~ id
            if (num > 7) && (num > (senders[WEEK_TOTAL] / 5)) # Ignore less than one per day 
              _li.list_group_item.list_group_item_danger "#{id} wrote: #{num}"
            elsif (num > 7) && (num > (senders[WEEK_TOTAL] / 10))
              _li.list_group_item.list_group_item_warning "#{id} wrote: #{num}"
            elsif (num > 7) && (num > (senders[WEEK_TOTAL] / 20))
              _li.list_group_item.list_group_item_info "#{id} wrote: #{num}"
            else
              _li.list_group_item "#{id} wrote: #{num}"
            end
            ctr += 1
            break if ctr >= 5
          end
        end
      end
    end
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
        "#{ENV['SCRIPT_NAME']}" => "List Traffic By Month",
        "#{ENV['SCRIPT_NAME']}?week" => "List Traffic By Week",
        "https://github.com/apache/whimsy/blob/master/www#{ENV['SCRIPT_NAME']}" => "See This Source Code"
      },
      helpblock: -> {
        _p %{
          This script displays some simple (and potentially lossy) analysis of traffic on the board@ mailing list.
          In particular, mapping email to a committer may not work (meaning individual senders may have multiple spots),
          and Subject lines displayed may be truncated (meaning threads may not fully be tracked).  Work in progress.
        }
        _p do
          _ 'This attempts to differentiate tool- or process-generated emails (NOTICE, REPORT, etc.) from all other emails (i.e. mails hand-written by a person). '
          _ 'Senders of more than 10% of all non-tool emails in a month are highlighted. '
          _ 'Senders of more than 20%, 10%, or 5% of all non-tool emails in a week are highlighted in the '
          _a 'By week view (supply ?week in URL).', href: ''
        end

      }
    ) do
      months = Dir["#{SRV_MAIL}/*"].map {|path| File.basename(path).untaint}.grep(/^\d+$/)
      if ENV['QUERY_STRING'].include? 'week'
        display_weekly(months: months, nondiscuss: MailUtils::NONDISCUSSION_SUBJECTS['<board.apache.org>'])
      else
        display_monthly(months: months, nondiscuss: MailUtils::NONDISCUSSION_SUBJECTS['<board.apache.org>'])
      end
    end
  end
end
