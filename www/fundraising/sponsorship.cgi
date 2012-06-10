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

path = ENV['PATH_INFO']
if path == '/'
  show = "ALL"
  title = "All Sponsors"
elsif path == "/overdue"
  show = "OVERDUE"
  title = "Overdue Sponsors"
elsif path == "/active"
  show = "ACTIVE"
  title = "Active Sponsors"
else
  show = "ALL"
  title = "All Sponsors"
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
      _span "|"
      _a "overdue", href: "overdue"
      _span "|"
      _a "active", href: "active"
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

      _tbody do
        sponsors.compact.each do |file, data|
          next if show == "ACTIVE" and data['status'] != 'active'

          date = data['sponsorship-renewal']
          isoverdue = date and Date.parse(date) < Date.today + 62
          next if show == "OVERDUE" and not isoverdue
 
          _tr_ do
            _td data['sponsorship-start']
            if isoverdue
              _td.remind date
             else
              _td date
             end

            _td! do
              _a data['name'], 
                href: "https://svn.apache.org/repos/#{sponsorship}/#{file}"
            end

            _td data['level']
            _td data['status']
          end
        end
      end
    end

    _script %{
      $("table").tablesorter({sortList: [[0,1]]});
      $('th').append('<span></span>');
    }
  end
end
