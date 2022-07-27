#!/usr/bin/env ruby

PAGETITLE = "ASF Mailing List Moderator Setup" # Wvisible:mail moderation

$LOAD_PATH.unshift '/srv/whimsy/lib'
require 'wunderbar'
require 'wunderbar/bootstrap'
require 'whimsy/asf'
require 'whimsy/asf/mlist'
require 'net/http'

# N.B. $USER and $PASSWORD are provided by wunderbar

user = ASF::Person.new($USER)
# authz handled by httpd

# get the mail names of the current podlings
current = ASF::Podling.current.map(&:mail_list)

pmcs = ASF::Committee.pmcs.map(&:mail_list)
ldap_pmcs = user.committees.map(&:mail_list)
ldap_pmcs += user.podlings.map(&:mail_list)
addrs = user.all_mail

tlp = []
podling = []
ASF::Mail.canmod(ldap_pmcs, false)
  .sort
  .map { |dom, lname, _lid|
    list = "#{lname}@#{dom}"
    host = dom.sub('.apache.org', '') # get the host name
    if pmcs.include? host
      tlp << list
    elsif current.include? host
      podling << list
    end
  }

# collect moderations
response = {}
ASF::MLIST.moderates(user.all_mail, response)
moderates = response[:moderates].transform_values { |v| v.join(' ')}

_html do
  # better system output styling (errors in red)
  _style :system
  _script src: 'assets/bootstrap-select.js'
  _link rel: 'stylesheet', href: 'assets/bootstrap-select.css'
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
        # _p do
        #   _ %{
        #     This form allows PMC and podling members to automatically add themselves as
        #     moderators for the lists associated with the PMC or podling.
        #   }
        # end
        # _p 'Anyone can remove themselves as a moderator of any list.'
        # _p do
        #   _span.text_info 'Note:'
        #   _ 'Only email address(es) associated with your Apache ID are listed here.  To'
        #   _span.strong 'change your associated email addresses'
        #   _ ', login to '
        #   _a 'your Whimsy personal details page', href: "https://whimsy.apache.org/roster/committer/__self__"
        #   _ 'where you can change your Forwarding Address(es) and alternate email addresses you may use.'
        # end
        # _p 'The moderation request will be activated synchronously (be patient, it may take a short while).'
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

    #   _h2 'BETA SOFTWARE - not yet in use.'
    #   _p %{
    #     The form should work, but no updates will be made.
    #     Please report any other issues to the Whimsy PMC.
    #   }

    #   ezmlmd_server = nil # prevent updates
      # get the EZMLM server id
      # ezmlmd_server = ASF::Config[:ezmlmd] || begin
      #   File.read('/home/whimsysvn/.ezmlmd').chomp
      # rescue StandardError
      #   _div.alert.alert_danger role: 'alert' do
      #     _ 'Mailing list server is not set up. No updates are possible.'
      #   end
      #   break # skip rest of page
      # end

    #   if tlp.size == 0 and podling.size == 0
    #     _fieldset do
    #       _legend 'Moderate A List'
    #       _p "Sorry, you cannot use this form to become a moderator"
    #     end
    #   else
    #     _form method: 'post', onSubmit: '$("#waitmod").show()' do
    #       _input type: 'hidden', name: 'request', value: 'sub'
    #       _fieldset do
    #         _legend 'Moderate A List'

    #         _label 'Select a mailing list first, then select the email address to moderate that list.'
    #         _ '(The dropdown only shows lists which you can automatically moderate)'
    #         _br
    #         _label 'List name:'
    #         _select name: 'list', data_live_search: 'true' do
    #           if tlp.size > 0
    #             _optgroup label: 'Top-Level Projects' do
    #               tlp.each do |list|
    #                 _option list
    #               end
    #             end
    #           end

    #           if podling.size > 0
    #             _optgroup label: 'Podlings' do
    #               podling.each do |list|
    #                 _option list
    #               end
    #             end
    #           end
    #         end

    #         _label 'Email:'
    #         _select name: 'addr' do
    #           addrs.each do |addr|
    #             _option addr
    #           end
    #         end

    #         _input type: 'submit', value: 'Submit Request'
    #         _span.waitmod! hidden: true do
    #           _b '... Please wait ...'
    #         end
    #         _p "(Last checked at: #{response[:modtime]})"
    #       end
    #     end
    #     _p do
    #       _b 'WARNING:'
    #       _ 'Some providers are known to block our emails as SPAM.'
    #       _ 'Please see the following for details: '
    #       _a 'email provider issues', href: 'emailissues', target: '_blank'
    #       _ ' (opens in new page)'
    #     end
    #   end

    #   _p
    #   _hr
    #   _p

    #   if moderates.size == 0
    #     _fieldset do
    #       _legend 'Stop moderating A List'
    #       _p "You don't currently moderate any lists"
    #       _p "(Last checked at: #{response[:modtime]})"
    #     end
    #   else
    #     _form method: 'post', onSubmit: '$("#waitunmod").show()' do
    #       _input type: 'hidden', name: 'request', value: 'unsub'
    #       _fieldset do
    #         _legend 'Stop moderating A List'

    #         _label 'Select the mailing list first, then select the moderation email address to remove.'
    #         _ '(The dropdown only shows lists which you currently moderate)'
    #         _br

    #         _label 'List name:'
    #         _select.ulist! name: 'list', data_live_search: 'true' do
    #           moderates.each do |list, emails|
    #             _option list, data_emails: emails
    #           end
    #         end

    #         _label 'Email:'
    #         _select.uaddr! name: 'addr' do
    #           addrs.each do |addr|
    #             _option addr
    #           end
    #         end

    #         _input type: 'submit', value: 'Submit Request'
    #         _span.waitunmod! hidden: true do
    #           _b '... Please wait ...'
    #         end
    #         _p "(Last checked at: #{response[:modtime]})"
    #       end
    #     end
    #   end
    #   _p

    #   if _.post?
    #     _hr
    #     lists = tlp + podling + moderates.keys
    #     unless addrs.include? @addr and lists.include? @list
    #       _h2_.text_danger {_span.label.label_danger 'Invalid Input'}
    #       _p 'Both email and list to subscribe to are required!'
    #       break
    #     end

    #     if ezmlmd_server
    #       path = [ezmlmd_server.chomp('/'), @request, @list, 'mod', $USER, @addr].join('/')
    #       begin
    #         response = Net::HTTP.get_response(URI(path))
    #       rescue StandardError
    #         response = nil
    #       end
    #     else
    #       response = OpenStruct.new(code: '',
    #           message: 'No server - would have requested: ',
    #           body: [@request, @list, 'mod', $USER, @addr].join('/')
    #         )
    #     end
    #     if response.is_a?(Net::HTTPSuccess)
    #       _div.alert.alert_success role: 'alert' do
    #         _p do
    #           _span.strong 'Request successful.'
    #         end
    #       end
    #     else
    #       _div.alert.alert_danger role: 'alert' do
    #         _p do
    #           _span.strong 'Request Failed:'
    #           if response
    #             _ response.code
    #             _ response.message
    #             _ response.body
    #           else
    #             _ 'Could not contact mailing list server'
    #           end
    #         end
    #       end
    #     end
    #   end

    #   _script %{
    #     $('select').selectpicker({});

    #     function select_emails() {
    #       var emails = $('#ulist option:selected').attr('data-emails').split(' ');
    #       var oldval = $('#addr').val();
    #       var newval = null;
    #       $('#uaddr option').each(function() {
    #         if (emails.indexOf($(this).text()) == -1) {
    #           this.disabled = true;
    #           if (this.textContent == oldval) oldval = null;
    #         } else {
    #           this.disabled = false;
    #           newval = newval || this.textContent;
    #         };
    #       });

    #       if (newval && !oldval) {
    #         $('#uaddr').val(newval);
    #         $('button[data-id=uaddr] .filter-option').text(newval);
    #       }

    #       $('#uaddr').selectpicker('render');
    #     }

    #     select_emails();

    #     $('#ulist').change(function() {
    #       select_emails();
    #     });
    #   }
    end
  end
end
