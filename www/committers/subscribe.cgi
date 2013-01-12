#!/usr/bin/ruby1.9.1
require 'wunderbar'
require 'mail'
require '/var/tools/asf'
require 'time'

$SAFE = 1

FORMAT_NUMBER = 2 # json format number

user = ASF::Person.new($USER)
# authz handled by httpd

lists = ASF::Mail.lists
lists.delete_if {|list| list =~ /^(ea|secretary|president|treasurer|chairman|committers)/ }
# TODO: for non-members, offer all public lists too
lists = ['infrastructure', 'jobs', 'site-dev', 'committers-cvs', 'site-cvs'] unless user.asf_member?
lists.sort!

addrs = (["#{$USER}@apache.org"] + user.mail + user.alt_email)

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
      Dir.chdir '/var/tools/infra/subreq'
      `svn update --non-interactive`
      fn = "#{$USER}-#{Time.now.strftime '%Y%m%d-%H%M%S.%L'}.json".untaint
      if File.exist? fn
        _h2_.error "Too many concurrent reuqests"
        break
      end

      vars = {
        version: FORMAT_NUMBER,
        availid: $USER,
        addr: @addr,
        listkey: @list,
      }
      request = JSON.pretty_generate(vars) + "\n"
      _pre request

      # commit it
      File.open(fn, 'w') { |file| file.write request }
      _.system(['svn', 'add', '--', fn])
      _.system [
        'svn', 'commit', ['--no-auth-cache', '--non-interactive'],
        '--with-revprop', "whimsy:author=#{$USER}",
        '-m', "#{@list}@ += #{$USER}",
        (['--username', $USER, '--password', $PASSWORD] if $PASSWORD),
        '--', fn
      ]
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
        pmcs = ASF::Committee.list.map(&:name)
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
  end
end
