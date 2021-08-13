#!/usr/bin/env ruby
PAGETITLE = "Overview of Whimsy Tools for Committers" # Wvisible:tools

$LOAD_PATH.unshift '/srv/whimsy/lib'
require 'json'
require 'whimsy/asf'
require 'wunderbar'
require 'wunderbar/bootstrap'

MISC = {
  'tools.cgi' => "Listing of all available Whimsy tools",
  'subscribe.cgi' => "Subscribe or unsubscribe from mailing lists",
  'moderationhelper.cgi' => "Get help with mailing list moderation commands"
}
_html do
  _body? do
    _whimsy_body(
      title: PAGETITLE,
      subtitle: 'Committer-restricted tools only',
      relatedtitle: 'More Useful Links',
      related: {
        "/committers/tools" => "Whimsy All Tools Listing",
        ASF::SVN.svnpath!('committers') => "Checkout the private 'committers' repo for Committers",
        "https://github.com/apache/whimsy/blob/master/www#{ENV['SCRIPT_NAME']}" => "See This Source Code",
        "mailto:dev@whimsical.apache.org?subject=[FEEDBACK] members/index idea" => "Email Feedback To dev@whimsical"
      },
      helpblock: -> {
        _p %{
          This script lists various Whimsy tools restricted to Committers.  These all deal with private or
          sensitive data, so be sure to keep confidential and do not share with non-committers.
        }
        _p do
          _ 'More questions?  See the '
          _a '/dev developer info pages', href: 'https://www.apache.org/dev/'
          _ ' or ask the '
          _a 'Community Development PMC', href: 'https://community.apache.org/'
          _ ' for pointers to everything Apache. REMINDER: This service is maintained by the Apache Whimsy PMC - if you have questions about OTHER Apache servers, please '
          _a 'Contact the Apache Infra team.', href: 'https://infra.apache.org/'
        end
      },
      breadcrumbs: {
        committers: '.'
      }
    ) do

      _h2 "Useful Committer-only Tools (require login)"
      _ul do
        MISC.each do |url, desc|
          _li do
            _a desc, href: url
            _ ' - '
            _code! do
              _a url, href: url
            end
          end
        end
      end
    end
  end
end
