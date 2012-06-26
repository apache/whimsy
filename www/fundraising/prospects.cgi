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
  title = "All Prospect Actions"
when "/today"
  show = "ACTIVE"
  title = "Prospect Actions due by Today"
when "/this-week"
  show = "THISWEEK"
  title = "This week's Prospect Actions"
else
  show = "ALL"
  title = "All Prospect Actions"
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
    # parse prospect records
    prospect_repo = 'private/foundation/Fundraising/prospects'
    sponsorship_repo = 'private/foundation/Fundraising/sponsorship'
    prospects = Dir["#{ASF::SVN[prospect_repo]}/*.yml"].map do |name| 
      file = File.read(name.untaint)
      _h2_ name
      file.gsub! /:\s*\?\s*\n/, ": '?'\n"    # make parseable
      data = YAML.load(file)
      next if String === data
      basename = File.basename(name.untaint)
      sponsor_file_path = "#{ASF::SVN[sponsorship_repo]}/#{basename}"
      if File.exists?(sponsor_file_path)
        sponsor_data = YAML.load(File.read(sponsor_file_path))
      else
        sponsor_data = {"name"=>basename}
      end
      [basename, data, sponsor_data]
    end

    _p do
      _a "all", href: "all"
      _ "|"
      _a "due by today", href: "today"
      _ "|"
      _a "this week", href: "this-week"
    end

   _table_ do
      _thead_ do
        _tr do
          _th 'By'
          _th 'Date'
          _th 'Prospect'
          _th 'Comment'
        end
      end
      _tbody do
        count=0
        prospects.compact.each do |file, data, sponsor|
          actions = data['action']
          if actions
            actions.each do |action|
              date = Date.parse(action['by-date'])
              today = Date.today()
              endofweek = (today + (5- today.cwday) %7)
              next if show == "TODAY" and date > today
              next if show == "THISWEEK" and date > endofweek
              _tr_ do
                _td action['by']
                if date < today
                  _td.remind action['by-date']
                else
                  _td action['by-date']
                end
                _td! do
                  _div sponsor
                  _a "#{sponsor['name']}", href: "https://svn.apache.org/repos/#{prospect_repo}/#{file}"
                end
                _td action['comment']
              end
              count=count+1
            end
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
