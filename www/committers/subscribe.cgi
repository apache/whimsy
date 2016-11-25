#!/usr/bin/env ruby
$LOAD_PATH.unshift File.realpath(File.expand_path('../../../lib', __FILE__))
require 'wunderbar'
require 'mail'
require 'whimsy/asf'
require 'time'

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
  _head_ do
    _title 'ASF Mailing List Self-subscription'
  end
  _body? do
    if _.post?
      unless addrs.include? @addr and lists.include? @list
        _h2_.error "Invalid input"
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
      _pre request

      SUBREQ = 'https://svn.apache.org/repos/infra/infrastructure/trunk/subreq'

      # add file to svn (--revision 0 means it won't overwrite an existing file)
      _.system ['svnmucc',
        ['--revision', '0'],
        '--message', "#{@list}@ += #{$USER}",
        '--with-revprop', "whimsy:author=#{$USER}",
         ['--no-auth-cache', '--non-interactive'],
         ['--root-url', SUBREQ],
         (['--username', $USER, '--password', $PASSWORD] if $PASSWORD),
        '--', 'put', '-', fn],
        stdin: request+ "\n" # seems to need extra EOL
      
      _p 'Request successful (unless indicated otherwise above). You will be subscribed within the hour.'

    end
    unless _.post?
    end
    _form method: 'post' do
      _fieldset do
        _legend 'ASF Mailing List Self-subscription'

        _label 'Subscribe'
        _select name: 'addr' do
          addrs.each do |addr|
            _option addr
          end
        end

        _ 'to'
        _select name: 'list' do
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
          _option '--- Foundation lists ---', disabled: 'disabled'
          lists.find_all { |list| seen[list] == 0 }.each do |list|
            _option list
          end
          _option '--- Top-Level Projects ---', disabled: 'disabled'
          lists.find_all { |list| seen[list] == 1 }.each do |list|
            _option list
          end
          _option '--- Podlings ---', disabled: 'disabled'
          lists.find_all { |list| seen[list] == 2 }.each do |list|
            _option list
          end
        end
        _input type: 'submit', value: 'Submit Request'
      end
    end
    _ 'Only your forwarding address and registered alternates are listed.'
    _ 'Visit'
    _a 'https://id.apache.org/', href: "https://id.apache.org/details/#{$USER}"
    _ 'to add or remove forwarding or alternate addresses.'
    _br
  end
end
