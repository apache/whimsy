#!/usr/bin/env ruby
PAGETITLE = "Example Whimsy Script With Styles" # Wvisible:tools Note: PAGETITLE must be double quoted

$LOAD_PATH.unshift File.realpath(File.expand_path('../../../lib', __FILE__))
require 'json'
require 'whimsy/asf'
require 'wunderbar'
require 'wunderbar/bootstrap'

_html do
  _body? do
    _whimsy_body2 title: "Sample New Whimsy Style", related: {
      "https://projects.apache.org/" => "Learn About Apache Projects",
      "https://community.apache.org/" => "Get Community Help",
      "https://github.com/apache/whimsy/" => "Read The Whimsy Code"
    } do
      _whimsy_panel "Your Data Here" do
        _p "This is where your code would output data or a form or whatever!"
        _p "All headers/footers and nicely wrapping a row is handled by themes.rb"
      end
      
    end
  end
end
