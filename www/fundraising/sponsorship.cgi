#!/usr/bin/ruby1.9.1
require 'wunderbar'
require '/var/tools/asf'
require 'yaml'
require 'date'

user = ASF::Person.new($USER)
unless user.asf_member? or ASF.pmc_chairs.include? user or $USER=='ea'
  print "Status: 401 Unauthorized\r\n"
  print "WWW-Authenticate: Basic realm=\"ASF Members and Officers\"\r\n\r\n"
  exit
end

level= nil
case ENV['PATH_INFO']
when '/'
  show = "ALL"
  title = "All Sponsors"
when "/overdue"
  show = "OVERDUE"
  title = "Overdue Sponsors"
when "/active"
  show = "ACTIVE"
  title = "Active Sponsors"
when "/unclear"
  show = "UNCLEAR"
  title = "Sponsors of Unknown Status"
else
  show = "ALL"
  level = ENV['PATH_INFO'][1,100]
  title = "All Sponsors: #{level}"
end

_html do
  _head_ do
    _title title
    _style %{
      th {border-bottom: solid black}
      table {border-spacing: 1em 0.2em }
      th span {float: right}
      th span:after {padding-left: 0.5em; content: "\u2195"}
      tr:hover {background-color: #FF8}
      .headerSortUp span:after {content: " \u2198"}
      .headerSortDown span:after {content: " \u2197"}
      .remind {color: red}
    }
    _script src: '/jquery.min.js'
    _script src: '/jquery.tablesorter.js'
  end
  _body? do
    # common banner
    _a href: 'https://id.apache.org/' do
      _img alt: "Logo", src: "https://id.apache.org/img/asf_logo_wide.png"
    end

    _h1_ title
    # parse sponsorship records
    sponsorship = 'private/foundation/Fundraising/sponsorship'
    sponsors = Dir["#{ASF::SVN[sponsorship]}/*.txt"].map do |name| 
      next if name =~ /payments.*\.txt/
      file = File.read(name.untaint)
      file.gsub! /:\s*\?\s*\n/, ": '?'\n"    # make parseable
      data = YAML.load(file)
      next if String === data
      data['date'] ||= data['invoice date']  # make uniform
      [File.basename(name), data]
    end

    _p do
      _a "all", href: "all"
      _ "|"
      _a "overdue", href: "overdue"
      _ "|"
      _a "active", href: "active"
      _ "|"
      _a "unclear", href: "unclear"
    end

    _p do
      _a "platinum", href: "platinum"
      _ "|"
      _a "gold", href: "gold"
      _ "|"
      _a "silver", href: "silver"
      _ "|"
      _a "bronze", href: "bronze"
      _ "|"
      _a "service", href: "service"
    end
 
    _table_ do
      _thead_ do
        _tr do
          _th 'Sponsorship Date'
          _th 'Renewal Date'
          _th 'Sponsor'
          _th 'Level'
          _th 'Status'
        end
      end

      count = 0
      _tbody do
        sponsors.compact.each do |file, data|
          next if show == "ACTIVE" and data['status'] != 'active'

          startdate = data['sponsorship-start']
          if startdate
            startdate = Date.parse(startdate)
            enddate = startdate.next_year
            isoverdue = enddate < (Date.today + 62)
          else
            enddate = nil
            isoverdue = false
          end

          next if show == "OVERDUE" and not isoverdue

          next if show == "UNCLEAR" and (data['sponsorship-start']!=nil and data['status']!=nil)

          next if not level.nil? and level != data['level']
          _tr_ do
            _td startdate
            if isoverdue
              _td.remind enddate
             else
              _td enddate
             end

            _td! do
              _a data['name'], 
                href: "https://svn.apache.org/repos/#{sponsorship}/#{file}"
            end

            _td data['level']
            _td data['status']
            count=count+1
          end
        end
        if count == 0
          _td "No sponsors found"
        end
      end
    end

    _script %{
      $("table").tablesorter({sortList: [[0,1]]});
      $('th').append('<span></span>');
    }
  end
end
