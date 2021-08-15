#!/usr/bin/env ruby
PAGETITLE = "Known problems with some email providers" # Wvisible:tools

$LOAD_PATH.unshift '/srv/whimsy/lib'
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
      subtitle: 'Overview',
      relatedtitle: 'More Useful Links',
      related: {
        "/committers/tools" => "Whimsy All Tools Listing",
        ASF::SVN.svnpath!('committers') => "Checkout the private 'committers' repo for Committers",
        "https://github.com/apache/whimsy/blob/master/www#{ENV['SCRIPT_NAME']}" => "See This Source Code",
        "mailto:dev@whimsical.apache.org?subject=[FEEDBACK] members/index idea" => "Email Feedback To dev@whimsical"
      },
      helpblock: -> {
        _p %{
          This page lists known problems communicating with some email providers.
        }
        _p %{
          Problems can occur when subscribers to our email lists report messages as SPAM.
          These may be genuine SPAM (though this is rare on most of our lists), or it may
          just that the subscriber has forgotten that they signed up to receive the emails.
          If enough customers of an email provider report our emails as SPAM, then the ASF domain may
          be blocked by the provider.
        }
        _p %{
          Once they become aware of such issues, our Infrastructure team will attempt to get
          the ban lifted, but that may take a while, and they may not be successful.
        }
        _p %{
          If you are using one of the problem domains and are having difficulty subscribing,
          or emails are not getting through, try using a different provider for
          communications with the ASF.
        }
      },
      breadcrumbs: {
        committers: '.',
        emailissues: 'emailissues'
      }
    ) do
      _h2 'Microsoft domains'
      _p %{
        There have been ongoing problems with Microsoft domains
        partly because many of their users report our legitimate email as spam.
      }
      _p %{
        The Infrastructure team have been trying to get the bans removed,
        but with no success. At present mails from one of the two ASF outbound
        servers are being rejected; i.e. on average 50% of mails will not be delivered.
      }
      _p 'The following Microsoft domains are all affected (as of August 2021):'
      _ul do
        _li 'hotmail.com'
        _li 'live.com'
        _li 'outlook.com'
      end
      _h2 'Other domains'
      _p %{
        TBA
      }
    end
  end
end
