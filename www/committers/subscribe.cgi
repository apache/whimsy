#!/usr/bin/env ruby
PAGETITLE = "ASF Mailing List Subscription Helper" # Wvisible:mail subscribe
$LOAD_PATH.unshift File.realpath(File.expand_path('../../../lib', __FILE__))
require 'wunderbar'
require 'wunderbar/bootstrap'
require 'mail'
require 'whimsy/asf'
require 'whimsy/asf/mlist'
require 'time'
require 'tmpdir'
require 'escape'

$SAFE = 1

FORMAT_NUMBER = 3 # json format number

# lists which are not eligible for self-subscription
BLACKLIST = %w{
  legal-internal
}

user = ASF::Person.new($USER)
# authz handled by httpd

# get the possible names of the current and retired podlings
current=[]
retired=[]
ASF::Podling.list.each {|p|
  names = p['resourceAliases'] # array, may be empty
  names.push p['resource'] # single string, always present
  status = p['status']
  if status == 'current'
    current.concat(names)
  elsif status == 'retired'
    retired.concat(names)
  end
}

pmcs = ASF::Committee.pmcs.map(&:mail_list)
lists = ASF::Mail.cansub(user.asf_member?, ASF.pmc_chairs.include?(user))
lists -= ASF::Mail.deprecated
lists -= BLACKLIST
lists.sort!
addrs = user.all_mail

_html do
  # better system output styling (errors in red)
  _style :system
  _script src: 'assets/bootstrap-select.js'
  _link rel: 'stylesheet', href: 'assets/bootstrap-select.css'
  _body? do
    _whimsy_body(
      title: PAGETITLE,
      subtitle: 'Mailing List Subscriptions',
      related: {
        'https://www.apache.org/foundation/mailinglists.html' => 'Apache Mailing List Info Page (How-to Subscribe Manually)',
        'https://lists.apache.org' => 'Apache Mailing List Archives',
        '/committers/moderationhelper.cgi' => 'Mailing List Moderation Helper',
        '/roster/committer/__self__' => 'Your Committer Details (and subscriptions)'
      },
      helpblock: -> {
        _p 'The below form allows Apache committers to automatically subscribe to, or unsubscribe from, most ASF mailing lists.'
        _p do
          _span.text_info 'Note:' 
          _ 'Only email address(es) associated with your Apache ID are listed here.  To'
          _span.strong 'change your associated email addresses'
          _ ', login to '
          _a 'https://id.apache.org/', href: "https://id.apache.org/details/#{$USER}"
          _ 'where you can change your primary Forwarding Address and any other associated Alias email addresses you use.'
        end
        _p do
          _ 'To view all your existing subscriptions (and email addresses), see your'
          _a 'committer details', href: '/roster/committer/__self__'
          _ '.'
        end
      }
    ) do
      
      seen = Hash.new
      lists.each do |list|
        ln = list.split('-').first
        ln = 'empire-db' if ln == 'empire'
        seen[list] = 0
        seen[list] = 1 if pmcs.include? ln
        seen[list] = 2 if current.include? ln
        seen[list] = 2 if (ln == 'incubator') \
        && (current.include? list.split('-')[1])
        seen[list] = 3 if retired.include? ln
        seen[list] = 3 if (ln == 'incubator') \
        && (retired.include? list.split('-')[1])
      end

      _form method: 'post' do
        _input type: 'hidden', name: 'request', value: 'sub'
        _fieldset do
          _legend 'Subscribe To A List'

          _label 'Select a mailing list first, then select the email address to subscribe to that list.'
          _ '(The dropdown only shows lists to which you can automatically subscribe)'
          _br
          _label 'List name:'
          _select name: 'list', data_live_search: 'true' do
            _optgroup label: 'Foundation lists' do
              lists.find_all { |list| seen[list] == 0 }.each do |list|
                _option list
              end
            end

            _optgroup label: 'Top-Level Projects' do
              lists.find_all { |list| seen[list] == 1 }.each do |list|
                _option list
              end
            end

            _optgroup label: 'Podlings' do
              lists.find_all { |list| seen[list] == 2 }.each do |list|
                _option list
              end
            end
          end

          _label 'Email:'
          _select name: 'addr' do
            addrs.each do |addr|
              _option addr
            end
          end

          _input type: 'submit', value: 'Submit Request'
        end
      end

      _p
      _hr
      _p

      _form method: 'post' do
        _input type: 'hidden', name: 'request', value: 'unsub'
        _fieldset do
          _legend 'Unsubscribe From A List'

          _label 'Select the mailing list first, then select the email address to unsubscribe.'
          _ '(The dropdown only shows lists to which you are subscribed)'
          _br
          _label 'List name:'
          # collect subscriptions
          response = {}
          ASF::MLIST.subscriptions(user.all_mail, response)
          subscriptions = response[:subscriptions].group_by {|list, mail| list}
          subscriptions = subscriptions.map do |list, names|
            list = $1 if list =~ /^(.*?)@apache\.org$/
            list = "#$2-#$1" if list =~ /^(.*?)@(.*?)\.apache\.org$/
            [list, names.map(&:last)]
          end.to_h

          _select.ulist! name: 'list', data_live_search: 'true' do
            _optgroup label: 'Foundation lists' do
              lists.find_all { |list| seen[list] == 0 }.each do |list|
                next unless subscriptions.include? list
                _option list, data_emails: subscriptions[list].join(' ')
              end
            end

            _optgroup label: 'Top-Level Projects' do
              lists.find_all { |list| seen[list] == 1 }.each do |list|
                next unless subscriptions.include? list
                _option list, data_emails: subscriptions[list].join(' ')
              end
            end

            _optgroup label: 'Podlings' do
              lists.find_all { |list| seen[list] == 2 }.each do |list|
                next unless subscriptions.include? list
                _option list, data_emails: subscriptions[list].join(' ')
              end
            end
          end

          _label 'Email:'
          _select.uaddr! name: 'addr' do
            addrs.each do |addr|
              _option addr
            end
          end

          _input type: 'submit', value: 'Submit Request'
        end
      end

      _p

      if _.post?
        _hr

        unless addrs.include? @addr and lists.include? @list
          _h2_.text_danger {_span.label.label_danger 'Invalid Input'} 
          _p 'Both email and list to subscribe to are required!'
          break
        end
        
        # Each user can only subscribe once to each list in each timeslot
        fn = "#{$USER}-#{@list}.json".untaint
        
        vars = {
          version: FORMAT_NUMBER,
          availid: $USER,
          addr: @addr,
          listkey: @list,
          # f3
          member_p: user.asf_member?,
          chair_p: ASF.pmc_chairs.include?(user),
        }
        request = JSON.pretty_generate(vars) + "\n"

        _div.well do
          if @request != 'unsub'
            _p 'Submitting subscribe request:'
          else
            _p 'Submitting unsubscribe request:'
          end

          _pre request
        end
        
        SUBREQ = 'https://svn.apache.org/repos/infra/infrastructure/trunk/subreq/'
        SUBREQ.sub! '/subreq', '/unsubreq' if @request == 'unsub'
        
        rc = 999

        Dir.mktmpdir do |tmpdir|
          tmpdir.untaint

          # commit using user's credentials if possible, otherwise use whisysvn
          if not $PASSWORD
            credentials = nil
          elsif user.asf_member?
            credentials = ['--username', $USER, '--password', $PASSWORD]
          else
            credentials = ['--username', 'whimsysvn']
          end

          _.system ['svn', 'checkout', SUBREQ, tmpdir,
            ['--no-auth-cache', '--non-interactive'], credentials]

          Dir.chdir tmpdir do

            if File.exist? fn
              File.write(fn, request + "\n")
              _.system ['svn', 'st']
            else
              File.write(fn, request + "\n")
              _.system ['svn', 'add', fn]
            end
 
            if @request != 'unsub'
              message = "#{@list} += #{$USER}"
            else
              message = "#{@list} -= #{$USER}"
            end
          
            rc = _.system ['svn', 'commit', fn, '--message', message,
              ['--no-auth-cache', '--non-interactive'], credentials]
          end
        end
        
        if rc == 0
          _div.alert.alert_success role: 'alert' do
            _p do
              _span.strong 'Request successfully submitted'
              if @request != 'unsub'
                _ 'You will be subscribed within the hour.'
              else
                _ 'You will be unsubscribed within the hour.'
              end
            end          
          end
        else
          _div.alert.alert_danger role: 'alert' do
            _p do
              _span.strong 'Request Failed, see above for details'
            end          
          end
        end
      end
    end

    _script %{
      $('select').selectpicker({});

      function select_emails() {
        var emails = $('#ulist option:selected').attr('data-emails').split(' ');
        var oldval = $('#addr').val();
        var newval = null;
        $('#uaddr option').each(function() {
          if (emails.indexOf($(this).text()) == -1) {
            this.disabled = true;
            if (this.textContent == oldval) oldval = null;
          } else {
            this.disabled = false;
            newval = newval || this.textContent;
          };
        });

        if (newval && !oldval) {
          $('#uaddr').val(newval);
          $('button[data-id=uaddr] .filter-option').text(newval);
        }

        $('#uaddr').selectpicker('render');
      }

      select_emails();

      $('#ulist').change(function() {
        select_emails();
      });
    }
  end
end
