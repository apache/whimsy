#!/usr/bin/env ruby
$LOAD_PATH.unshift File.realpath(File.expand_path('../../lib', __FILE__))

=begin
APP to generate the correct ezmlm syntax for moderators
=end

require 'wunderbar'
require 'wunderbar/bootstrap'
require 'whimsy/asf'

$SAFE = 1

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
        'http://untroubled.org/ezmlm/manual/Sending-commands.html#Sending-commands' => 'EZMLM Command Help'
      },
      helpblock: -> {
        _p 'This form generates ezmlm mailing list addresses for various moderator requests.'
        _p do
          _ 'Enter the ASF mailing list name, select the operation to perform, and enter a subscriber email (if needed).'
          _br
          _ 'Press Generate.  The To: address below can be copy/pasted into an email to send.  In most cases you must be a moderator for that list.'
        end
        _p do
          _span.text_danger 'BETA SOFTWARE: double-check the command first. '
          _a "Feedback welcome!", href: "mailto:dev@whimsical.apache.org?Subject=Feedback on moderation helper app"
        end
      }
    ) do
      _form method: 'post' do
        _fieldset do
          _legend 'Mail Moderation Helper'

          _table do
            _tr do
              _th 'Mailing list information'
              _th 'Subscriber updates'
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
              _td do
                _label do
                  _input type: "radio", name: "cmd", value: "list", required: true, checked: false
                  _ 'list (current subscribers)'
                end
              end
              _td do
                _label do
                  _input type: "radio", name: "cmd", value: "subscribe", required: true, checked: false
                  _ 'subscribe (normal subscription: can post and gets messages)'
                end
              end
            end
            _tr do
              _td do
                _label do
                  _input type: "radio", name: "cmd", value: "log", required: true, checked: false
                  _ 'log (history of changes to the subscribers)'
                end
              end
              _td do
                _label do
                  _input type: "radio", name: "cmd", value: "unsubscribe", required: true, checked: true
                  _ 'unsubscribe'
                end
              end
            end
            _tr do
              _td do
                _label do
                  _input type: "radio", name: "cmd", value: "allow-list", required: true, checked: false
                  _ 'allow-list (currently allowed to post)'
                end
              end
              _td do
                _label do
                  _input type: "radio", name: "cmd", value: "allow-subscribe", required: true, checked: false
                  _ 'allow-subscribe (allow posting without getting messages)'
                end
              end
            end
            _tr do
              _td do
                _label do
                  _input type: "radio", name: "cmd", value: "allow-log", required: true, checked: false
                  _ 'allow-log (history)'
                end
              end
              _td do
                _label do
                  _input type: "radio", name: "cmd", value: "allow-unsubscribe", required: true, checked: false
                  _ 'allow-unsubscribe (drop allow posting)'
                end
              end
            end
            _tr do
              _td do
                _label do
                  _input type: "radio", name: "cmd", value: "deny-list", required: true, checked: false
                  _ 'deny-list (currently denied to post)'
                end
              end
              _td do
                _label do
                  _input type: "radio", name: "cmd", value: "deny-subscribe", required: true, checked: false
                  _ 'deny-subscribe (prevent posting)'
                end
              end
            end
            _tr do
              _td do
                _label do
                  _input type: "radio", name: "cmd", value: "deny-log", required: true, checked: false
                  _ 'deny-log (historic)'
                end
              end
              _td do
                _label do
                  _input type: "radio", name: "cmd", value: "deny-unsubscribe", required: true, checked: false
                  _ 'deny-unsubscribe (remove from list of denied posters)'
                end
              end
            end
            _tr do
              _td '(above commands operate on the list only)'
              _td '(above commands also require a subscriber email address)'
            end
          end
          _p do
            _ul do
              _li 'subscribers can post and will receive mail'
              _li 'allow-subscribers can post; they do not get copies of mails (this is used for e.g. press@)'
              _li 'deny-subscribers cannot post; their posts will be rejected without needing moderation'
            end
          end
          _input type: 'submit', value: 'Generate'
        end
      end

      if _.post?
        _div.well do
          ml0,ml1 = @maillist.split('@')
          if ml1
            ml1 += '.apache.org'
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
