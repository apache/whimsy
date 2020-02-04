#!/usr/bin/env ruby
PAGETITLE = "401 - Unauthorized Error - Apache Whimsy"
$LOAD_PATH.unshift '/srv/whimsy/lib'
require 'wunderbar'
require 'wunderbar/bootstrap'
require 'whimsy/asf'

_html do
  _body? do
    _whimsy_body(
    title: PAGETITLE,
    subtitle: "URL #{ENV['REDIRECT_URL']} Unauthorized",
    style: 'panel-danger',
    related: {
      "/" => "Whimsy Server Homepage",
      "/committers/tools" => "Whimsy All Tools Listing",
      "https://github.com/apache/whimsy/blob/master/www#{ENV['SCRIPT_NAME']}" => "See This Source Code",
      "mailto:dev@whimsical.apache.org?subject=[SITE] 401 Error Page #{ENV['REDIRECT_URL']}" => "Questions? Email Whimsy PMC"
    },
    helpblock: -> {
      _p do
        _span.label.label_danger '401'
        _ " Tsk, tsk, that's secret magician stuff.  Sorry, but a good magician never reveals their tricks - you're not allowed to peek. "
        _ "You must be a member of #{ENV['Www-Authenticate']} to view this page. "
        _ "Use the same login credentials as you do for your Apache account at: "
        _a 'https://id.apache.org/', href: 'https://id.apache.org/'
      end
    }
    ) do
        # No-op
        params = _.params
        params.each do |k,v|
          _p "Param: #{k} #{v}"
        end
        _p "foo #{_.referer} "
          _p "bar #{_.content_type} "
        ENV.sort.each do |k,v|
          if k.eql? 'HTTP_AUTHORIZATION'
              # cannot use sub! because value is fozen
              # redact non-empty string
              if v and not v.empty?
                v = '<redacted>'
              end
          end
          _p "ENV: #{k} #{v}"
        end
    end
  end
end
