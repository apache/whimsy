#!/usr/bin/env ruby
PAGETITLE = "Server error log listing" # Wvisible:debug
$LOAD_PATH.unshift File.realpath(File.expand_path('../../../lib', __FILE__))
require 'json'
require 'whimsy/asf'
require 'wunderbar'
require 'wunderbar/bootstrap'
require 'whimsy/logparser'

_html do
  _body? do
    _whimsy_body(
      title: PAGETITLE,
      subtitle: 'Simplified listing of interesting log entries',
      relatedtitle: 'More Useful Links',
      related: {
        '/members/log' => 'Full server error and access logs',
        '/docs' => 'Whimsy code and API documentation',
        "https://github.com/apache/whimsy/blob/master/www#{ENV['SCRIPT_NAME']}" => 'See This Source Code'
      },
      helpblock: -> {
        _p 'This parses error.log and whimsy_error.log and displays a condensed version, in time order (approximate).'
        _p do
          _span.text_warning 'Reminder: '
          _span.glyphicon.glyphicon_lock :aria_hidden
          _ ' Log data is private to ASF Members; do not distribute any logs.'
        end
      }
    ) do
      _whimsy_panel_table(
        title: 'Partial error listing',
        helpblock: -> {
          _ 'This only includes a subset of possibly interesting error log entries.'
          _a 'See the full server logs directory.', href: '/members/log'
        }
      ) do
        logs = LogParser.get_errors()
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
                  _td do
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
  end
end
