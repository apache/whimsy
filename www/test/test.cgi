#!/usr/bin/env ruby
PAGETITLE = "Example Whimsy Script With Styles" # Wvisible:tools Note: PAGETITLE must be double quoted

$LOAD_PATH.unshift File.realpath(File.expand_path('../../../lib', __FILE__))
require 'json'
require 'whimsy/asf'
require 'wunderbar'
require 'wunderbar/bootstrap'

_html do
  _body? do
    _whimsy_body(
      title: PAGETITLE, 
      related: {
        "https://whimsy.apache.org/committers/tools" => "Whimsy Tool Listing",
        "https://incubator.apache.org/images/incubator_feather_egg_logo_sm.png" => "Incubator Logo",
        "https://community.apache.org/" => "Get Community Help",
        "https://github.com/apache/whimsy/" => "Read The Whimsy Code"
      },
      helpblock: -> {
        _p "This www/test/test.cgi script shows a proposed new way to write whimsy tools."
        _p "Using lib/whimsy/theme and _whimsy_body2 means users have a consistent UI for different tools, 
        and means that simple descriptions or help documentation are included at the start of each tool."
        _p "Similarly, having a listing of related tools in the right hand panel helps end users find other interesting tools here."
      }
    ) do
      _whimsy_panel_table(
        title: "Your Table Title Here",
        helpblock: -> {
          _p "Explain any additional details (if needed) about your table data here."
        }
      ) do
        _table.table.table_hover.table_striped do
          _thead_ do
            _tr do
              _th 'Row Number'
              _th 'Column Two'
            end
            _tbody do
              datums = ["Fred", "Francie", "Flubber"]
              [1, 2, 3].each do | row |
                _tr_ do
                  _td do
                    _ row
                  end
                  _td do
                    _ datums[row]
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
