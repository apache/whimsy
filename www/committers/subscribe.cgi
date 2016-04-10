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

# TODO dedup, copied from mlreq
class Podlings
  def self.list
    return @list if @list
    # extract the names of podlings (and aliases) from podlings.xml
    require 'nokogiri'
    incubator_content = ASF::SVN['asf/incubator/public/trunk/content']
      current = Nokogiri::XML(File.read("#{incubator_content}/podlings.xml")).
      search('podling[status=current]')
    podlings = current.map {|podling| podling['resource']}
    podlings += current.map {|podling| podling['resourceAliases']}.compact.
      map {|names| names.split(/[, ]+/)}.flatten
    @list = podlings
  end
end

lists = ASF::Mail.lists
lists.delete_if {|list| list =~ /^(ea|secretary|president|treasurer|chairman|committers$)/ }
lists.delete_if {|list| list =~ /(^|-)security$|^security(-|$)/ }

pmcs = ASF::Committee.list.map(&:mail_list)
seen = Hash.new
lists.each do |list|
  seen[list] = 0
  seen[list] = 1 if pmcs.include? list.split('-').first
  seen[list] = 2 if Podlings.list.include? list.split('-').first
  seen[list] = 2 if (list.split('-').first == 'incubator') \
                    && (Podlings.list.include? list.split('-')[1])
end

unless user.asf_member?
  # non-members only see specifically whitelisted foundation lists as well
  # as all non-private committee lists
  whitelist = ['infrastructure', 'jobs', 'site-dev', 'committers-cvs',
     'site-cvs', 'concom', 'party']
  lists.delete_if {|list| seen[list] < 1 and not whitelist.include? list}
  lists.delete_if {|list| list =~ /-private$/}
  lists += ['board'] if ASF.pmc_chairs.include? user
end

lists.sort!

addrs = (["#{$USER}@apache.org"] + user.mail + user.alt_email)

_html do
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
            seen[list] = 0
            seen[list] = 1 if pmcs.include? list.split('-').first
            seen[list] = 2 if Podlings.list.include? list.split('-').first
            seen[list] = 2 if (list.split('-').first == 'incubator') \
                              && (Podlings.list.include? list.split('-')[1])
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
