#!/usr/bin/env ruby
PAGETITLE = "404 - Not Found Error - Apache Whimsy"
$LOAD_PATH.unshift '/srv/whimsy/lib'
require 'wunderbar'
require 'wunderbar/bootstrap'
require 'whimsy/asf'

_html do
  _body? do
    _whimsy_body(
    title: PAGETITLE,
    subtitle: "URL #{ENV['REDIRECT_URL']} Not Found",
    style: 'panel-danger',
    related: {
      "/" => "Whimsy Server Homepage",
      "/committers/tools" => "Whimsy All Tools Listing",
      "https://github.com/apache/whimsy/blob/master/www#{ENV['SCRIPT_NAME']}" => "See This Source Code",
      "mailto:dev@whimsical.apache.org?subject=[SITE] 404 Error Page #{ENV['REDIRECT_URL']}" => "Questions? Email Whimsy PMC"
    },
    helpblock: -> {
      _p do
        _span.label.label_danger '404'
        _ " Whatever you're looking for at "
        _code ENV['REDIRECT_URL']
        _ " is not there.  We'll double-check our crystal balls, but you should probably try another "
        _a 'magic link.', href: '/'
      end
    }
    ) do
        # No-op
    end
  end
end
