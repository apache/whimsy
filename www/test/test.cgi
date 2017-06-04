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
      _whimsy_panel "Your Data Here" do
        _p "This is where your code would output data or a form or whatever!"
        _p "All headers/footers and nicely wrapping a row is handled by themes.rb"
      end
    end
  end
end
