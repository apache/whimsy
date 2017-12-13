#!/usr/bin/env ruby
PAGETITLE = "Whimsy Code Documentation" # Wvisible:docs

$LOAD_PATH.unshift File.realpath(File.expand_path('../../../lib', __FILE__))
require 'json'
require 'whimsy/asf'
require 'wunderbar'
require 'wunderbar/bootstrap'

_html do
  _body? do
    _whimsy_body(
      title: PAGETITLE,
      subtitle: 'About This Documentation',
      relatedtitle: 'More Useful Links',
      related: {
        "/committers/tools" => "Whimsy Tool Listing",
        "https://github.com/rubys/wunderbar/" => "See Wunderbar Module Documentation",
        "https://github.com/apache/whimsy/blob/master/www#{ENV['SCRIPT_NAME']}" => "See This Source Code"
      },
      helpblock: -> {
        _p %{
          This is the homepage for the code and API documentation for the Apache Whimsy project.
        }
      }
    ) do

      _h2 "API Documentation"
      _a "whimsy/asf module APIs", href: '/docs/api/'
    end
  end
end
