#!/usr/bin/env ruby
PAGETITLE = "Apache Whimsy Code Documentation" # Wvisible:docs

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
        "/committers/tools" => "Listing of All Whimsy Tools",
        "https://github.com/rubys/wunderbar/" => "Wunderbar Module Documentation",
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
      _a 'Developer Overview FAQs', href: 'https://github.com/apache/whimsy/blob/master/DEVELOPMENT.md'
    end
  end
end
