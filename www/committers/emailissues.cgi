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
          If enough customers of an email provider report our emails, then the ASF domain may
          be blocked by the provider.
        }
      },
      breadcrumbs: {
        committers: '.',
        emailissues: 'emailissues'
      }
    ) do
      _h2 'Microsoft domains'
      _p %{
        Unfortunately, Microsoft continues to block our email as so many of their users report
        our legitimate email as spam.
      }
      _p %{
        We have not had much success in getting them to unblock us,
        so you will need to use a different provider for communication with apache.org addresses.
      }
      _p 'The following domains are all affected (as of August 2021):'
      _ul do
        _li 'hotmail.com'
        _li 'live.com'
        _li 'outlook.com'
      end
  end
  end
end
