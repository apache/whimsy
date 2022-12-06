#!/usr/bin/env ruby
$LOAD_PATH.unshift '/srv/whimsy/lib'

=begin
APP to generate the correct ezmlm syntax for moderators
=end

require 'wunderbar'
require 'wunderbar/bootstrap'
require 'whimsy/asf'

_html do
  # ensure the generated text is selected ready for copy-pasting
  _script %{
    window.onload=function() {
      var sel = window.getSelection();
      sel.removeAllRanges();
      var range = document.createRange();
      var dest = document.getElementById('dest');
      range.selectNodeContents(dest);
      sel.addRange(range);
      // TODO auto copy to clipboard (tricky)
    }
  }

  _body? do
    _whimsy_body(
      title: 'Mail List Moderation Helper',
      subtitle: 'How-To Use Moderator Commands',
      related: {
        'https://www.apache.org/foundation/mailinglists.html' => 'Apache Mailing List Info Page',
        'https://lists.apache.org' => 'Apache Mailing List Archives',
        '/committers/subscribe.cgi' => 'Mailing List Subscription Helper',
        'http://www.apache.org/foundation/mailinglists.html#subscribing' => 'Information on Subscribing/Unsubscribing',
        'http://apache.org/dev/committers.html#mail-moderate' => 'Guide for moderators',
        'http://apache.org/dev/committers.html#problem_posts' => 'Guide for moderators - dealing with problem posts',
        'http://untroubled.org/ezmlm/manual/Sending-commands.html#Sending-commands' => 'EZMLM Command Help',
        'https://issues.apache.org/jira/browse/INFRA-10476' => 'INFRA-10476 - Provide a way to force specific subscribers to be moderated'
      },
      helpblock: -> {
        _p 'This form generates ezmlm mailing list addresses for various moderator requests.'
        _p do
          _b 'N.B. Only list moderators can make these requests. Requests from non-moderators will be rejected (or possibly ignored).'
        end
        _p do
          _ 'Enter the ASF mailing list name, select the operation to perform, and enter a subscriber email (if needed).'
          _br
          _ 'Press Generate.  The To: address below can be copy/pasted into an email to send.  In most cases you must be a moderator for that list.'
          _br
          _span.text_danger 'Note that you must send the email from the address which is registered as a moderator.'
        end
        _p do
          _ul do
            _li 'subscribers can post and will receive mail'
            _li 'allow-subscribers can post; they do not get copies of mails (this is used for e.g. press@. Also useful for bots.)'
            _li 'deny-subscribers cannot post; their posts will be rejected without needing moderation'
            _li 'sendsubscribertomod-subscribers will have all posts moderated (for posters who are borderline problems) - ask INFRA to enable the setting for the list'
          end
        end
        _p do
          _span.text_danger 'BETA SOFTWARE: double-check the command first. '
          _a "Feedback welcome!", href: "mailto:dev@whimsical.apache.org?Subject=Feedback on moderation helper app"
        end
        _p do
          _span '** If you are not a moderator, you can contact them by emailing <list>-owner@<tlp>.apache.org **'
        end
      }
    ) do
      _form method: 'post' do
        _fieldset do
          _table do
            _tr do
              _th 'Mailing list'
              _th 'Subscriber'
            end
            _tr do
              _td do
                _input.name name: 'maillist', size: 40, pattern: '[^@]+@([-\w]+)?', required: true, value: @maillist,
                  placeholder: 'user@project or announce@'
                _ '.apache.org '
              end
              _td do
                _input.name name: 'email', size: 40, pattern: '[^@]+@[^@]+', value: @email, placeholder: 'user@domain.example'
              end
            end
            _tr do
              _td ''
              _td do
                _p do
                  _b 'WARNING'
                  _ 'Some providers are known to block our emails as SPAM.'
                  _br
                  _ 'Please see the following for details: '
                  _a 'email provider issues', href: '../committers/emailissues', target: '_blank'
                  _ ' (opens in new page)'
                end
              end
            end
            _tr do
              _td {
                _br
                _p 'The following commands operate on the list only:'
              }
              _td {
                _br
                _p 'The following commands also require a subscriber email address:'
              }
            end
            _tr do
              _td do
                _label do
                  _input type: "radio", name: "cmd", value: "list", required: true, checked: (@cmd == "list")
                  _ 'list (current subscribers)'
                end
              end
              _td do
                _label do
                  _input type: "radio", name: "cmd", value: "subscribe", required: true, checked: (@cmd == "subscribe")
                  _ 'subscribe (normal subscription: can post and gets messages)'
                end
              end
            end
            _tr do
              _td do
                _label do
                  _input type: "radio", name: "cmd", value: "log", required: true, checked: (@cmd == "log")
                  _ 'log (history of subscription changes)'
                end
              end
              _td do
                _label do
                  _input type: "radio", name: "cmd", value: "unsubscribe", required: true, checked: (@cmd == "unsubscribe" || @cmd == nil)
                  _ 'unsubscribe (from list)'
                end
              end
            end
            _tr do
              _td do
                _label do
                  _input type: "radio", name: "cmd", value: "allow-list", required: true, checked: (@cmd == "allow-list")
                  _ 'allow-list (currently allowed to post)'
                end
              end
              _td do
                _label do
                  _input type: "radio", name: "cmd", value: "allow-subscribe", required: true, checked: (@cmd == "allow-subscribe")
                  _ 'allow-subscribe (allow posting without getting messages - e.g. for bots)'
                end
              end
            end
            _tr do
              _td do
                _label do
                  _input type: "radio", name: "cmd", value: "allow-log", required: true, checked: (@cmd == "allow-log")
                  _ 'allow-log (history of subscriptions to allow list)'
                end
              end
              _td do
                _label do
                  _input type: "radio", name: "cmd", value: "allow-unsubscribe", required: true, checked: (@cmd == "allow-unsubscribe")
                  _ 'allow-unsubscribe (drop allow posting)'
                end
              end
            end
            _tr do
              _td do
                _label do
                  _input type: "radio", name: "cmd", value: "deny-list", required: true, checked: (@cmd == "deny-list")
                  _ 'deny-list (list those currently denied to post)'
                end
              end
              _td do
                _label do
                  _input type: "radio", name: "cmd", value: "deny-subscribe", required: true, checked: (@cmd == "deny-subscribe")
                  _ 'deny-subscribe (prevent subscriber from posting)'
                end
              end
            end
            _tr do
              _td do
                _label do
                  _input type: "radio", name: "cmd", value: "deny-log", required: true, checked: (@cmd == "deny-log")
                  _ 'deny-log (history of deny subscriptions)'
                end
              end
              _td do
                _label do
                  _input type: "radio", name: "cmd", value: "deny-unsubscribe", required: true, checked: (@cmd == "deny-unsubscribe")
                  _ 'deny-unsubscribe (remove from list of denied posters)'
                end
              end
            end
            _tr do
              _td do
                _label do
                  _input type: "radio", name: "cmd", value: "sendsubscribertomod-list", required: true, checked: (@cmd == "sendsubscribertomod-subscribe")
                  _ 'sendsubscribertomod-list (list of moderated subscribers)'
                end
              end
              _td do
                _label do
                  _input type: "radio", name: "cmd", value: "sendsubscribertomod-subscribe", required: true, checked: (@cmd == "sendsubscribertomod-subscribe")
                  _ 'sendsubscribertomod-subscribe (add to list of moderated subscribers - ask INFRA to enable this for the list)'
                end
              end
            end
            _tr do
              _td do
                _label do
                  _input type: "radio", name: "cmd", value: "sendsubscribertomod-log", required: true, checked: (@cmd == "sendsubscribertomod-subscribe")
                  _ 'sendsubscribertomod-log (history of moderated subscribers)'
                end
              end
              _td do
                _label do
                  _input type: "radio", name: "cmd", value: "sendsubscribertomod-unsubscribe", required: true, checked: (@cmd == "sendsubscribertomod-unsubscribe")
                  _ 'sendsubscribertomod-unsubscribe (remove from list of moderated subscribers)'
                end
              end
            end
          end
          _p {
            _br
            _input type: 'submit', value: 'Generate'
          }
        end
      end

      if _.post?
        _div.well do
          ml0,ml1 = @maillist.split('@')
          if ml1
            # enable escape for apachecon.com
            ml1 += '.apache.org' unless ml1 =~ /\.(org|com)$/
          else
            ml1 = 'apache.org'
          end
          em = @email.split('@')
          _br
          if @cmd.end_with? 'subscribe' # also catches unsubscribe
            unless @email.length > 0
              _h3.error 'Need subscriber email address'
              break
            end
            dest = "#{ml0}-#{@cmd}-#{em[0]}=#{em[1]}@#{ml1}"
          else
            dest = "#{ml0}-#{@cmd}@#{ml1}"
          end
          _span 'Copy this email address: '
          _span.dest! dest
          _br
          _br
          _a 'or Click to Send Mail', href: "mailto:#{dest}?Subject=#{dest}"
        end
      end
    end
  end
end
