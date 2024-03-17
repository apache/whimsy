#!/usr/bin/env ruby

PAGETITLE = "ASF Mailing List Moderator Setup" # Wvisible:mail moderation

# NO LONGER ACTIVE - see webmod.apache.org

$LOAD_PATH.unshift '/srv/whimsy/lib'
require 'wunderbar'
require 'wunderbar/bootstrap'
require 'whimsy/asf' # for _whimsy_body

_html do
  _body? do
    _whimsy_body(
      title: PAGETITLE,
      subtitle: 'Mailing List Moderator Maintenance',
      related: {
        'https://www.apache.org/foundation/mailinglists.html' =>
          'Apache Mailing List Info Page (How-to Subscribe Manually)',
        'https://lists.apache.org' => 'Apache Mailing List Archives',
        '/committers/moderationhelper.cgi' => 'Mailing List Moderation Helper',
        '/roster/committer/__self__' => 'Your Committer Details (and subscriptions)'
      },
      helpblock: -> {
        _p do
            _ 'PMC members can now update the moderator lists for their project lists'
            _ 'using the'
            _a 'webmod tool', href: 'https://webmod.apache.org/modreq.html?action=modreq'
            _ 'provided by INFRA'
        end
        _p do
          _ 'To view all your existing moderations (and email addresses), see your'
          _a 'committer details', href: '/roster/committer/__self__'
          _ '.'
        end
      }
    ) do
      _h4 do
        _ 'No longer in use - please see'
        _a 'webmod.apache.org', href: 'https://webmod.apache.org/modreq.html?action=modreq'
      end
      _br
      _br
    end
  end
end
