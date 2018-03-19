#!/usr/bin/env ruby
PAGETITLE = "Overview of Whimsy Tools for Members" # Wvisible:meeting

$LOAD_PATH.unshift File.realpath(File.expand_path('../../../lib', __FILE__))
require 'json'
require 'whimsy/asf'
require 'wunderbar'
require 'wunderbar/bootstrap'

MEETING = {
  'proxy.cgi' => "Assign a proxy for the (current) Member's meeting",
  'watch.cgi' => "Potential Member Watch List - tracking candidates for future nominations",
  'memberless-pmcs.cgi' => "Crosscheck PMCs with few/no ASF Members, for future nominations",
  'nominations.cgi' => "Member nominations cross-check - ensuring nominations get on the ballot, etc.",
  'attendance-xcheck.cgi' => "Member's Meeting Attendance Cross-Check - who attended when",
  'non-participants.cgi' => "Active Members not participating in recent meetings (to send a poll to)",
  'inactive.cgi' => "Poll of Inactive Members - tool to query non-participating members why",
  'whatif.cgi' => "Board STV Results 'what-if' tool - review past board election votes"
}

MISC = {
  'subscriptions.cgi' => "Apache members@ List Subscription Crosscheck",
  'security-subs.cgi' => "Security Mailing Lists Subscription Check",
  'namediff.cgi' => "Crosscheck Members Names With ICLA records",
  'mirror_check.cgi' => "ASF Distribution Mirror Check - is a mirror configured correctly"
}
_html do
  _body? do
    _whimsy_body(
      title: PAGETITLE,
      subtitle: 'Member-restricted tools only',
      relatedtitle: 'More Useful Links',
      related: {
        "/committers/tools" => "Whimsy All Tools Listing",
        "https://svn.apache.org/repos/private/foundation/" => "Checkout the private 'foundation' repo for Members",
        "https://github.com/apache/whimsy/blob/master/www#{ENV['SCRIPT_NAME']}" => "See This Source Code",
        "mailto:dev@whimsical.apache.org?subject=[FEEDBACK] members/index idea" => "Email Feedback To dev@whimsical"
      },
      helpblock: -> {
        _p %{
          This script lists various Whimsy tools restricted to Members.  These all deal with private or 
          sensitive data, so be sure to keep confidential.
        }
        _p %{
          Coming soon: pointers to the calendar and process around Member's Meetings, and the various tools that help automate tasks.
        }
      },
      breadcrumbs: {
        members: '/committers/tools#members',
        meeting: '/committers/tools#meeting'
      }
    ) do
    
      _h2 "Tools related to Member's Meetings (Nominations, Voting, Proxy, etc.)"
      _ul do
        MEETING.each do |url, desc|
          _li do
            _a desc, href: url
            _ ' - '
            _code! do
              _a url, href: url
            end
          end
        end
      end
      _h2 "Miscellaneous Tools - private mailing list checks, etc."
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
