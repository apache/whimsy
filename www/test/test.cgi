#!/usr/bin/env ruby
PAGETITLE = 'Example Whimsy Script With Styles '# Wvisible:tools

$LOAD_PATH.unshift File.realpath(File.expand_path('../../../lib', __FILE__))
require 'json'
require 'whimsy/asf'
require 'wunderbar'
require 'wunderbar/bootstrap'
require 'whimsy/asf/themes'

_html do
  _body? do
    _whimsy_body title: "This is title", foo: "bar", related: {
      "https://www.apache.org/foundation/marks/resources" => "Trademark Site Map",
      "https://www.apache.org/foundation/marks/list/" => "Official Apache Trademark List",
      "https://www.apache.org/foundation/marks/contact" => "Contact Us About Trademarks"
    } do
      _p "bare paragraph"
    end
  end
end
