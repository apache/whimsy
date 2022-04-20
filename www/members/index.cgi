#!/usr/bin/env ruby
PAGETITLE = "Overview of Whimsy Tools for Members" # Wvisible:meeting

$LOAD_PATH.unshift '/srv/whimsy/lib'
require 'json'
require 'whimsy/asf'
require 'wunderbar'
require 'wunderbar/bootstrap'

MEETING = {
  'meeting.cgi' => "Member's Meeting FAQ, Timeline, How-Tos",
  'proxy.cgi' => "Assign a proxy for the (current) Member's meeting",
  'watch.cgi' => "Potential Member Watch List - tracking candidates for future nominations",
  'memberless-pmcs.cgi' => "Crosscheck PMCs with few/no ASF Members, for future nominations",
  'nominations.cgi' => "Member's nominations cross-check - ensuring nominations get on the ballot, etc.",
  'board-nominations.cgi' => "Board nominations cross-check - ensuring nominations get on the ballot, etc.",
  'attendance-xcheck.cgi' => "Member's Meeting Attendance cross-check - who attended when",
  'non-participants.cgi' => "Active Members not participating in recent meetings (to send a poll to)",
  'inactive.cgi' => "Poll of Inactive Members - tool to query non-participating members why",
  'whatif.cgi' => "Board STV Results 'what-if' tool - review past board election votes"
}

LISTS = {
  '/committers/subscribe.cgi' => "Subscribe or unsubscribe from any mailing list",
  'list-traffic.cgi' => "Statistics about members@ mailing list traffic",
  '/officers/list-traffic.cgi' => "Statistics about board@ mailing list traffic",
  'subscriptions.cgi' => "Apache members@ List Subscription Crosscheck",
  'security-subs.cgi' => "Security Mailing Lists Subscription Check",
  'mailing_lists.cgi' => "Apache Mailing List Info",
  'moderator_checks.cgi' => "Apache List Moderator checks"
}

MISC = {
  'mentors.cgi' => "New Member mentoring program overview",
  'board-attend.cgi' => "Director attendance statistics at board meetings",
  'board-nominations.cgi' => "Board Member nominations cross-check - ensuring nominations get on the ballot, etc.",
  'ldap-namecheck.cgi' => "Crosscheck LDAP Names With Public Name from ICLAs",
  'namediff.cgi' => "Crosscheck Members Names With ICLA records",
  'mirror_check.cgi' => "ASF Distribution Mirror Check - is a mirror configured correctly",
  'download_check.cgi' => "Verify an Apache project download page is configured correctly"
}

_html do
  _body? do
    _whimsy_body(
      title: PAGETITLE,
      subtitle: 'Member-restricted tools only',
      relatedtitle: 'More Useful Links',
      related: {
        "/committers/tools" => "Whimsy All Available Tools Listing",
        ASF::SVN.svnpath!('foundation') => "Checkout the private 'foundation' repo for Members",
        "https://github.com/apache/whimsy/blob/master/www#{ENV['SCRIPT_NAME']}" => "See This Source Code",
        "mailto:dev@whimsical.apache.org?subject=[FEEDBACK] members/index idea" => "Email Feedback To dev@whimsical"
      },
      helpblock: -> {
        _p %{
          This script lists various Whimsy tools restricted to Members.  These all deal with private or
          sensitive data, so be sure to keep confidential.
        }
        _p do
          _ 'For more information about ASF Governance and what it means to be a Member, see the '
          _a 'Membership Governance overview.', href: 'https://www.apache.org/foundation/governance/members'
        end
      },
      breadcrumbs: {
        members: '.',
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
      _h2 "Tools related to mailing lists"
      _ul do
        LISTS.each do |url, desc|
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
