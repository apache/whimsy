#!/usr/bin/env ruby
PAGETITLE = "Server error log listing" # Wvisible:debug
$LOAD_PATH.unshift '/srv/whimsy/lib'
require 'json'
require 'whimsy/asf'
require 'wunderbar'
require 'wunderbar/bootstrap'
require 'whimsy/logparser'

# Emit table of interesting error logs
def display_errors(current)
  _whimsy_panel_table(
    title: 'Partial error listing',
    helpblock: -> {
      _ "This only includes a subset of possibly interesting error log entries from the #{current ? 'current day' : 'past week'}."
      _a 'See the full server logs directory (by date, descending)', href: '/members/log?C=M;O=D'
    }
  ) do
    logs = LogParser.get_errors(current)
    _table.table.table_hover.table_striped do
      _thead_ do
        _tr do
          _th 'Date/Time'
          _th ''
          _th 'Error text or array of errors'
        end
        _tbody do
          logs.each do | key, val |
            _tr_ do
              _td :class => 'nowrap' do
                _ key
              end
              _td do
                if val.is_a?(Array)
                  _span.glyphicon.glyphicon_remove_circle :aria_hidden, aria_label: 'List of code errors'
                elsif /Passenger/ =~ val
                  _span.glyphicon.glyphicon_briefcase :aria_hidden, aria_label: 'Passenger server message'
                else
                  _span.glyphicon.glyphicon_remove_sign :aria_hidden, aria_label: 'stderr line from code'
                end
              end
              _td do
                if val.is_a?(Array)
                  val.each do |i|
                    _ i
                    _br
                  end
                else
                  _ val
                end
              end
            end
          end
        end
      end
    end
  end
end

# Emit table of interesting access logs (optional, with ?access)
def display_access()
  apps, misses = LogParser.get_access_reports()
  _p do
    _ 'This only includes a subset of possibly interesting access log entries from the current day, roughly categorized by major application (board, roster, etc.)'
    _a 'See the full server logs directory.', href: '/members/log'
  end
  _h2 'Access Log Synopsis - by Path or Tool'
  listid = 'applist'
  _div.panel_group id: listid, role: 'tablist', aria_multiselectable: 'true' do
    apps.each_with_index do |(name, data), n|
      itemtitle = LogParser::WHIMSY_APPS[name] ? LogParser::WHIMSY_APPS[name] : 'All Other URLs'
      itemtitle << " (#{data['remote_user'].sum{|k,v| v}})" if data['remote_user']
      _whimsy_accordion_item(listid: listid, itemid: name, itemtitle: itemtitle, n: n, itemclass: 'panel-info') do
        _table.table.table_hover.table_striped do
          _thead_ do
            _tr do
              _th 'User list'
              _th 'URLs hit (total)'
            end
            _tbody do
              _tr_ do
                _td do
                  data['remote_user'].each do |remote_user|
                    _ remote_user
                  end
                end
                _td do
                  data['uri'].sort.each do |uri|
                    _ uri
                    _br
                  end
                end
              end
            end
          end
        end
      end
    end
  end
  _whimsy_panel('Access Log Synopsis - Error URLs', style: 'panel-warning') do
    _p 'This is a simplistic listing of all URLs with 4xx/5xx error codes (excluding obvious bot URLs).'
    erruri = {}
    errref = {}
    misses.each do |h|
      erruri[h['uri']] = ''
      errref[h['referer']] = ''
    end
    _h3 'URIs hit that returned 4xx/5xx errors'
    _ul do
      erruri.keys.sort.each do |u|
        _li u
      end
    end
    _h3 'Referrers for all above 4xx/5xx errors'
    _ul do
      errref.keys.sort.each do |u|
        _li u
      end
    end
  end
end

_html do
  _style %{
    .nowrap {
      white-space: nowrap;
    }
  }
  _body? do
    _whimsy_body(
      title: PAGETITLE,
      subtitle: 'Simplified listing of interesting log entries',
      relatedtitle: 'More Useful Links',
      related: {
        '/members/log' => 'Full server error and access logs',
        '/docs' => 'Whimsy code and API documentation',
        '/status' => 'Whimsy production server status',
        "https://github.com/apache/whimsy/blob/master/www#{ENV['SCRIPT_NAME']}" => 'See This Source Code'
      },
      helpblock: -> {
        _p 'This parses error.log and whimsy_error.log and displays a condensed version, in time order (approximate) of today\'s entries.'
        _p do
          _a 'Append "?week"', href: "#{ENV['SCRIPT_NAME']}?week"
          _ ' to the URL to get error results for the last week, and '
          _a 'append "?access"', href: "#{ENV['SCRIPT_NAME']}?access"
          _ ' to parse the access logs instead.'
        end
        _p do
          _span.text_warning 'Reminder: '
          _span.glyphicon.glyphicon_lock :aria_hidden
          _ ' Log data is private to ASF Members; do not distribute any logs.'
        end
      }
    ) do
      # Display whimsy_access.log data if requested (takes longer)
      if ENV['QUERY_STRING'].include? 'access'
        display_access()
      else
        # Append ?week to search all *.log|*.log.gz in dir
        display_errors(!ENV['QUERY_STRING'].include?('week'))
      end
    end
  end
end