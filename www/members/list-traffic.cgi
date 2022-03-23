#!/usr/bin/env ruby
PAGETITLE = "Members@ Mailing List Statistics" # Wvisible:members
$LOAD_PATH.unshift '/srv/whimsy/lib'

require 'wunderbar'
require 'wunderbar/bootstrap'
require 'wunderbar/jquery'
require 'whimsy/asf'
require 'whimsy/asf/agenda'
require 'date'
require 'mail'
require '../../tools/mboxhdr2csv.rb'
require 'whimsy/asf/meeting-util'

user = ASF::Person.new($USER)
unless user.asf_member?
  print "Status: 401 Unauthorized\r\n"
  print "WWW-Authenticate: Basic realm=\"ASF Members\"\r\n\r\n"
  exit
end

# Return sorted data in JSON format if the query string includes 'json'
ENV['HTTP_ACCEPT'] = 'application/json' if ENV['QUERY_STRING'].include? 'json'

LIST_ROOT = 'members'
MAIL_ROOT = '/srv/mail' # TODO: this should be config item
SRV_MAIL = File.join(MAIL_ROOT, LIST_ROOT)

WEEK_TOTAL = '@@total' # Use @@ so it can't match who name/emails
WEEK_START = '@@start'
COHORT_STYLES = { # TODO find better ways to colorize
  'Zero to two years' => 'text-warning',
  'Two to five years' => 'text-success',
  'Five to ten years' => 'text-info',
  'Ten or more years' => 'text-primary',
  'Non-members' => 'text-muted'
}

# Define simple styles for various 'ages' of Members
# 1-2 years, 3-5 years, 5-10 years, 10+ years
def style_cohorts(cohorts)
  today = Date.today.year
  cohorts['cohorts'].each do |id, date|
    case date[0,4].to_i
    when (today-1)..today
      cohorts['cohorts'][id] = COHORT_STYLES['Zero to two years']
    when (today-5)...(today-1)
      cohorts['cohorts'][id] = COHORT_STYLES['Two to five years']
    when (today-10)...(today-5)
      cohorts['cohorts'][id] = COHORT_STYLES['Five to ten years']
    else
      cohorts['cohorts'][id] = COHORT_STYLES['Ten or more years']
    end
  end
end

# Display monthly statistics for all available data
def display_monthly(months:, nondiscuss:, cohorts:)
  months.sort.reverse.each do |month|
    data = MailUtils.get_mails_month(mailroot: SRV_MAIL, yearmonth: month, nondiscuss: nondiscuss)
    next if data.empty?
    _h1 "#{LIST_ROOT}@ statistics for #{month} (total mails: #{data[MailUtils::MAILS].length})", id: month
    _div.row do
      _div.col_sm_6 do
        _ul.list_group do
          _li.list_group_item.active.list_group_item_info "Top Ten Email Senders"
          ctr = 0
          data[MailUtils::MAILCOUNT].each do |id, num|
            if num > (data[MailUtils::MAILS].length / 10)
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
          _li.list_group_item.list_group_item_info "Long Tail - All Senders"
          _li.list_group_item do
            data[MailUtils::MAILCOUNT].each do |name, num|
              id = (name.match(/.+[(](\w+)/) || [])[1]
              if cohorts['cohorts'].has_key?(id)
                _span! "#{name} (#{num}), ", class: cohorts['cohorts'][id]
              else
                _span! "#{name} (#{num}), ", class: cohorts['cohorts'][COHORT_STYLES['Non-member']]
              end
            end
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
    data = MailUtils.get_mails_month(mailroot: SRV_MAIL, yearmonth: month, nondiscuss: nondiscuss)
    next if data.empty?
    # accumulate all mails in order for weeks, through all months
    data[MailUtils::MAILS].each do |m|
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
  _h1 "#{LIST_ROOT}@ list emails weekly statistics", id: "top"
  _div.row do
    _div.col.col_sm_offset_1.col_sm_9 do
      weeks.sort.reverse.each do |week, senders|
        total = 0
        senders.each do |sender, count|
          next if /@@/ =~ sender
          total += count
        end
        senders[WEEK_TOTAL] = total
        _ul.list_group do
          _li.list_group_item.active.list_group_item_info "Week #{week} Top Senders (total mails: #{senders[WEEK_TOTAL]})", id: week
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
        "/members/index" => "More Member-Specific Tools",
        "/officers/list-traffic" => "Board@ List Traffic",
        ENV['SCRIPT_NAME'] => "Members@ List Traffic By Month",
        "#{ENV['SCRIPT_NAME']}?week" => "Members@ List Traffic By Week",
        "https://github.com/apache/whimsy/blob/master/www#{ENV['SCRIPT_NAME']}" => "See This Source Code"
      },
      helpblock: -> {
        _p %{
          This script displays simple (and likely slightly lossy) analysis of traffic on the #{LIST_ROOT}@ mailing list.
          In particular, mapping From: email to a committer may not work (meaning individual senders may have multiple spots
          or be miscategorized).  Work in progress.  Server only stores last year of mail.
        }
        _p do
          _ 'Senders of more than 10% of all emails in a month are highlighted. '
          _ 'Senders of more than 20%, 10%, or 5% of all emails in a week are highlighted in the '
          _a 'By week view (supply ?week in URL).', href: '?week'
        end
        _p do
          _ 'For the All Senders column, Members are colorized by approximate years of membership like so: '
          _br
          COHORT_STYLES.each do |name, style|
            _span "#{name}, ", class: style
          end
          _ ' note that due to email address variations, some entries may be incorrectly marked.'
        end
      }
    ) do
      months = Dir["#{SRV_MAIL}/*"].map {|path| File.basename(path)}.grep(/^\d+$/)
      attendance = ASF::MeetingUtil.get_attendance(ASF::SVN['Meetings'])
      style_cohorts(attendance) if attendance.has_key?('cohorts') # Allow to fail silently if data missing
      # if ENV['QUERY_STRING'].include? 'Clear-Cache-No-Really'
      #   _p do # Danger, Will Robinson!
      #     _ 'Note: deleting cached .json files: '
      #     cache = Dir["#{SRV_MAIL}/??????.json"]
      #     ctr = 0
      #     cache.each do |f|
      #       File.delete(f)
      #       ctr += 1
      #     end
      #     _ "Successfully deleted #{ctr} files (will be rebuilt now)."
      #   end
      # end
      if ENV['QUERY_STRING'].include? 'week'
        display_weekly(months: months, nondiscuss: MailUtils::NONDISCUSSION_SUBJECTS["<#{LIST_ROOT}.apache.org>"])
      else
        display_monthly(months: months, nondiscuss: MailUtils::NONDISCUSSION_SUBJECTS["<#{LIST_ROOT}.apache.org>"], cohorts: attendance)
      end
    end
  end
end

# Return just sorted data counts as JSON
_json do
  months = Dir["#{SRV_MAIL}/*"].map {|path| File.basename(path)}.grep(/^\d+$/)
  data = Hash.new {|h, k| h[k] = {} }
  months.sort.reverse.each do |month|
    tmp = MailUtils.get_mails_month(mailroot: SRV_MAIL, yearmonth: month, nondiscuss: MailUtils::NONDISCUSSION_SUBJECTS["<#{LIST_ROOT}.apache.org>"])
    next if tmp.empty?
    data[month][MailUtils::TOOLCOUNT] = tmp[MailUtils::TOOLCOUNT]
    data[month][MailUtils::MAILCOUNT] = tmp[MailUtils::MAILCOUNT]
  end
  data
end
