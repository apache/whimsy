#!/usr/bin/env ruby
PAGETITLE = "ASF Mailing List Subscription Helper" # Wvisible:mail subscribe
$LOAD_PATH.unshift '/srv/whimsy/lib'
require 'wunderbar'
require 'wunderbar/bootstrap'
require 'whimsy/asf'
require 'whimsy/asf/mlist'

FORMAT_NUMBER = 3 # json format number

user = ASF::Person.new($USER)
# authz handled by httpd

# get the possible names of the current, graduated and retired podlings
current = []
retired = []
graduated = [] # if no longer a PMC then this is the same as retired
ASF::Podling.list.each {|p|
  names = p['resourceAliases'] # array, may be empty
  names.push p['resource'] # single string, always present
  status = p['status']
  if status == 'current'
    current.concat(names)
  elsif status == 'retired'
    retired.concat(names)
  elsif status == 'graduated'
    graduated.concat(names)
  end
}

pmcs = ASF::Committee.pmcs.map(&:mail_list)

# hack to get access to pmcs etc
define_method(:gettype) do |dom|
  return :ASF if dom == 'apache.org'
  host = dom.sub('.apache.org', '') # get the host name
  return :TLP if pmcs.include? host
  return :PPMC if current.include? host
  return :TLP if dom.end_with? '.apache.org'
  return nil if retired.include? host or graduated.include? host
  return :ASF
end

ldap_pmcs = [] # No need to get the info for ASF members
ldap_pmcs = user.committees.map(&:mail_list) unless user.asf_member?
# Also allow podling private lists to be subscribed by podling owners
ldap_pmcs += user.podlings.map(&:mail_list) unless user.asf_member?
addrs = user.all_mail

listtype = {} # key: list@dom, value: list type: ASF|TLP|PPMC

lists = ASF::Mail.cansub(user.asf_member?, ASF.pmc_chairs.include?(user), ldap_pmcs, false)
  .map { |dom, lname, _list|
    listid = lname + '@' + dom
    type = gettype(dom)
    listtype[listid] = type if type
    [dom, lname]
  }.sort.map {|d, l| "#{l}@#{d}"}


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
          _a 'your Whimsy personal details page', href: "https://whimsy.apache.org/roster/committer/__self__"
          _ 'where you can change your Forwarding Address(es) and alternate email addresses you may use.'
        end
        _p 'ASF members can use this form to subscribe to private lists. PMC chairs can subscribe to board lists. (P)PMC members can subscribe to their private@ list.'
        _p 'The subscription request will be queued and should be processed within about an hour.'
        _p do
          _ 'To subscribe to other private lists, send an email to the list-subscribe@ address and wait for the request to be manually approved.'
          _ 'This might take a day or two.'
        end
        _p do
          _ 'To view all your existing subscriptions (and email addresses), see your'
          _a 'committer details', href: '/roster/committer/__self__'
          _ '.'
        end
      }
    ) do

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
              lists.find_all { |list| listtype[list] == :ASF }.each do |list|
                _option list
              end
            end

            _optgroup label: 'Top-Level Projects' do
              lists.find_all { |list| listtype[list] == :TLP }.each do |list|
                _option list
              end
            end

            _optgroup label: 'Podlings' do
              lists.find_all { |list| listtype[list] == :PPMC }.each do |list|
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
      _p do
        _br
        _b 'WARNING'
        _ 'Some providers are known to block our emails as SPAM.'
        _br
        _ 'Please see the following for details: '
        _a 'email provider issues', href: 'emailissues', target: '_blank'
        _ ' (opens in new page)'
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
          # collect subscriptions
          subscriptions = ASF::MLIST.subscriptions(user.all_mail)[:subscriptions].
            select { |listid, _| ASF::Mail.unsubbable? listid}. # can we unsubscribe from this list?
            group_by {|listid, _mail| listid}. # allow for multiple subs to single list
            transform_values {|v| v.map(&:last)} # pick out the emails

          # fill in any missing types
          subscriptions.each_key do |list|
            listtype[list] ||= gettype(list.split('@')[-1]) || :ASF
          end

          _label 'List name:'
          _select.ulist! name: 'list', data_live_search: 'true' do
            _optgroup label: 'Foundation lists' do
              subscriptions.select { |list, _| listtype[list] == :ASF }.each do |list, emails|
                _option list, data_emails: emails.join(' ')
              end
            end

            _optgroup label: 'Top-Level Projects' do
              subscriptions.select { |list, _| listtype[list] == :TLP }.each do |list, emails|
                _option list, data_emails: emails.join(' ')
              end
            end

            _optgroup label: 'Podlings' do
              subscriptions.select { |list, _| listtype[list] == :PPMC }.each do |list, emails|
                _option list, data_emails: emails.join(' ')
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

        # subreq/unsubreq now accept name@dom
        # Keep the key for the file name
        listkey = ASF::Mail.listdom2listkey(@list)

        # Each user can only subscribe once to each list in each timeslot
        fn = "#{$USER}-#{listkey}.json"

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
          if @request == 'unsub'
            _p 'Submitting unsubscribe request:'
          else
            _p 'Submitting subscribe request:'
          end

          _pre request
        end

        SUBREQ = ASF::SVN.svnpath!('subreq')
        SUBREQ.sub! '/subreq', '/unsubreq' if @request == 'unsub'

        rc = 999

        Dir.mktmpdir do |tmpdir|

          # commit using user's credentials if possible, otherwise use whisysvn
          if not $PASSWORD
            credentials = {}
          elsif user.asf_member?
            credentials = {user: $USER, password: $PASSWORD}
          else
            credentials = {user: 'whimsysvn'}
          end

          ASF::SVN.svn_('checkout', [SUBREQ, tmpdir], _, credentials)

          Dir.chdir tmpdir do

            if File.exist? fn
              File.write(fn, request + "\n")
              ASF::SVN.svn('status', '.')
            else
              File.write(fn, request + "\n")
              ASF::SVN.svn('add', fn)
            end

            if @request == 'unsub'
              message = "#{@list} -= #{$USER}"
            else
              message = "#{@list} += #{$USER}"
            end

            options = credentials.merge({msg: message})
            rc = ASF::SVN.svn_('commit', fn, _, options)
          end
        end

        if rc == 0
          _div.alert.alert_success role: 'alert' do
            _p do
              _span.strong 'Request successfully submitted.'
              if @request == 'unsub'
                _ 'You will be unsubscribed within the hour.'
              else
                _ 'You will be subscribed within the hour.'
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
