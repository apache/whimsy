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

_html do
  _head_ do
    _title 'Fundraising Sponsors'
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

    _h1_ 'Fundraising Sponsors'

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

    _table_ do
      _thead_ do
        _tr do
          _th 'Date'
          _th 'Sponsor'
          _th 'Level'
        end
      end

      _tbody do
        sponsors.compact.each do |file, data|
          _tr_ do
            date = data['date'].to_s.sub(/(\d\d\d\d)(\d\d)(\d\d)/, '\1-\2-\3')
            parsed = Date.parse(date) rescue Date.new
            if parsed >= Date.today-366 and parsed <= Date.today-305
              _td.remind date
             else
              _td date
             end

            _td! do
              _a data['name'], 
                href: "https://svn.apache.org/repos/#{sponsorship}/#{file}"
            end

            _td data['level']
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
