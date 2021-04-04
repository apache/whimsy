#!/usr/bin/env ruby
PAGETITLE = "Overview of Whimsy Tools for Officers" # Wvisible:meeting

$LOAD_PATH.unshift '/srv/whimsy/lib'
require 'json'
require 'whimsy/asf'
require 'wunderbar'
require 'wunderbar/bootstrap'

OFFICERS = {
  '/board/agenda' => "Monthly Board Agenda Tool",
  'acreq.cgi' => "New Account Request Helper",
  'mlreq.cgi' => "New Mailing List Request Form",
  '/committers/subscribe.cgi' => "Apache Mailing List Subscription/Unsubscription Tool",
  '/board/subscriptions' => "PMC Chair board@ Subscription Crosscheck",
  'list-traffic.cgi' => "Statistics About The board@ Mailing List",
  'board-stats.cgi' => "Statistics About Board Meetings",
  '/treasurer/bill-upload' => "Treasurer's Bill Upload Helper",
  'http://treasurer.apache.org' => "Treasurer's Office Payment Processing Overview",
  'https://www.apache.org/foundation/governance/orgchart' => "Apache Corporate Organization Chart",
  'coi.cgi' => "Conflict of Interest Affirmation / Lookup Tool"
}

_html do
  _body? do
    _whimsy_body(
      title: PAGETITLE,
      subtitle: 'Officer and Member-restricted tools only',
      relatedtitle: 'More Useful Links',
      related: {
        "/committers/tools" => "Whimsy All Available Tools Listing",
        ASF::SVN.svnpath!('foundation', 'officers') => "Checkout the private 'foundation/officers' repo for Officers",
        "https://github.com/apache/whimsy/blob/master/www#{ENV['SCRIPT_NAME']}" => "See This Source Code",
        "mailto:dev@whimsical.apache.org?subject=[FEEDBACK] members/index idea" => "Email Feedback To dev@whimsical"
      },
      helpblock: -> {
        _p %{
          This script lists various Whimsy tools restricted to Officers of the ASF (including PMC Chairs) or to Members.  These often deal with private or
          sensitive data, so be sure to keep confidential.
        }
        _p do
          _ 'For more information about ASF Governance see the '
          _a 'Governance overview.', href: 'https://www.apache.org/foundation/governance/'
        end
      }
    ) do

      _h2 "Tools Useful For ASF Officers"
      _ul do
        OFFICERS.each do |url, desc|
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
