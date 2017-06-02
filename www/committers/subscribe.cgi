#!/usr/bin/env ruby
PAGETITLE = "ASF Mailing List Self-subscription" # Wvisible:mail subscribe
$LOAD_PATH.unshift File.realpath(File.expand_path('../../../lib', __FILE__))
require 'wunderbar'
require 'wunderbar/bootstrap'
require 'mail'
require 'whimsy/asf'
require 'time'
require 'tmpdir'
require 'escape'

$SAFE = 1

FORMAT_NUMBER = 3 # json format number

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

pmcs = ASF::Committee.list.map(&:mail_list)
lists = ASF::Mail.cansub(user.asf_member?, ASF.pmc_chairs.include?(user))
lists.sort!
addrs = (["#{$USER}@apache.org"] + user.mail + user.alt_email)

_html do
  # better system output styling (errors in red)
  _style :system
  _script src: 'assets/bootstrap-select.js'
  _link rel: 'stylesheet', href: 'assets/bootstrap-select.css'
  _body? do
    _whimsy_body(
      title: PAGETITLE,
      subtitle: 'How To Subscribe',
      related: {
        'https://www.apache.org/foundation/mailinglists.html' => 'Apache Mailing List Info Page',
        'https://lists.apache.org' => 'Apache Mailing List Archives',
        'https://whimsy.apache.org/committers/moderationhelper.cgi' => 'Mailing List Moderation Helper'
      },
      helpblock: -> {
        _ 'This page allows Apache committers to auto-subscribe to various mailing lists.'
        _span.text_info 'Note:' 
        _ 'Only your registered email address(es) are listed here. To change your email addresses, login to '
        _a 'https://id.apache.org/', href: "https://id.apache.org/details/#{$USER}"
        _ 'to add or remove forwarding or alternate addresses.'
      }
    ) do
      
      _form method: 'post' do
        _fieldset do
          _legend PAGETITLE
          _label 'Subscribe'
          _select name: 'addr' do
            addrs.each do |addr|
              _option addr
            end
          end
          
          _ 'to'
          _select name: 'list', data_live_search: 'true' do
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
          _input type: 'submit', value: 'Submit Request'
        end
      end

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
          _p 'Submitting subscribe request:'
          _pre request
        end
        
        SUBREQ = 'https://svn.apache.org/repos/infra/infrastructure/trunk/subreq/'
        
        rc = 999

        Dir.mktmpdir do |tmpdir|
          tmpdir.untaint

          _.system ['svn', 'checkout', SUBREQ, tmpdir,
            ['--no-auth-cache', '--non-interactive'],
            (['--username', $USER, '--password', $PASSWORD] if $PASSWORD)]

          Dir.chdir tmpdir do

            if File.exist? fn
              File.write(fn, request + "\n")
              _.system ['svn', 'st']
            else
              File.write(fn, request + "\n")
              _.system ['svn', 'add', fn]
            end
          
            rc = _.system ['svn', 'commit', fn,
              '--message', "#{@list}@ += #{$USER}",
              ['--no-auth-cache', '--non-interactive'],
              (['--username', $USER, '--password', $PASSWORD] if $PASSWORD)]
          end
        end
        
        if rc == 0
          _div.alert.alert_success role: 'alert' do
            _p do
              _span.strong 'Request successfully submitted'
              _ 'You will be subscribed within the hour.'
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
    }
  end
end
