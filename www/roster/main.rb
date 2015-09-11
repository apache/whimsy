#!/usr/bin/ruby

#
# Server side router/controllers
#

require 'whimsy/asf'
require 'whimsy/asf/podlings'
require 'whimsy/asf/site'

require 'wunderbar/sinatra'
require 'wunderbar/bootstrap/theme'
require 'wunderbar/angularjs/route'
require 'wunderbar/jquery/filter'
require 'wunderbar/underscore'
require 'ruby2js/filter/functions'

require_relative 'model/ldap'

set :views, File.dirname(__FILE__)

get '/' do
  @base = env['REQUEST_URI']
  _html :'views/main'
end

get %r{/(committer/(.*))} do |path, name|
  if request.xhr? or env['HTTP_ACCEPT'].include? 'application/json'
    _json do
      person = ASF::Person.find(name)
      if person and person.public_name
        _availid person.id
        _name person.public_name 
        _emails person.all_mail
        _urls person.urls
        _committees person.committees.map(&:name)
        _member person.asf_member?
        _banned person.banned? if person.banned?
        _pgpkeys (person.pgp_key_fingerprints || [])
        _groups person.groups.map(&:name)
        _auth person.auth
      else
        throw :halt, 404
      end
    end
  else
    @base = URI.parse(env['REQUEST_URI']).path.chomp(path)
    _html :'views/main'
  end
end

get %r{/(committee/.*)} do |path|
  @base = URI.parse(env['REQUEST_URI']).path.chomp(path)
  _html :'views/main'
end

get %r{/(group/.*)} do |path|
  @base = env['REQUEST_URI'].chomp(path)
  _html :'views/main'
end

get '/js/:file.js' do
  _js :"js/#{params[:file]}"
end

get '/partials/:file.html' do
  _html :"partials/#{params[:file]}"
end

configure do
  @ldap_cache = nil
  @ldap_etag = nil
end

get '/json/auth' do
  _json do
    _asf Hash[ASF::Authorization.new('asf').map {|group, list| [group, list]}]
    _pit Hash[ASF::Authorization.new('pit').map {|group, list| [group, list]}]
  end
end

get '/json/podlings' do
  _json do
    _! Hash[ASF::Podlings.new.map {|podling, definition| [podling, definition]}]
  end
end

get '/json/site' do
  _json do
    _! ASF::Site.list
  end
end

get '/json/info' do
  _json do
    committees = ASF::Committee.load_committee_info
    _! Hash[committees.map { |committee| 
      [committee.name.gsub(/[^-\w]/,''), {
        display_name: committee.display_name,
        report: committee.report,
        chair: committee.chair ? committee.chair.id : nil,
        memberUid: committee.info,
        names: committee.names,
        emeritus: committee.emeritus,
        pmc: !ASF::Committee.nonpmcs.include?(committee)
      }]
    }]
  end
end

LDAP_ETAGS=[]
get '/json/ldap' do
  cache_control :private, :no_cache, :must_revalidate, max_age: 0

  cache_control = env['HTTP_CACHE_CONTROL'].to_s.downcase.split(/,\s+/)
  if cache_control.include? 'only-if-cached'
    etag = request.env['HTTP_IF_NONE_MATCH']
    if LDAP_ETAGS.include? etag
      throw :halt, 304
    else
      throw :halt, 504 unless @ldap_cache
    end
  else
    @ldap_cache = JSON.dump(ASF::RosterLDAP.get)
    @ldap_etag = Digest::MD5.hexdigest(@ldap_cache)

    unless LDAP_ETAGS.include? @ldap_etag
      LDAP_ETAGS << @ldap_etag 
      LDAP_ETAGS.slice! 0, LDAP_ETAGS.length-20
    end
  end

  etag @ldap_etag if @ldap_etag
  @ldap_cache
end

get '/json/mail' do
  _json do
    _! ASF::Mail.lists(true)
  end
end

get '/json/members' do
  user = env['REMOTE_USER'] ||= ENV['USER'] || Etc.getpwuid.name
  if ASF::Person.find(user).asf_member?
    _json do
      _! ASF::Member.list
    end
  else
    halt 403, "Not authorized\n"
  end
end

get '/json/changes' do
  scripts = ASF::SVN['private/foundation/board/scripts']
  record = File.read("#{scripts}/pmc-changes-record.txt")

  changes = {}

  ASF::Committee.load_committee_info.each do |pmc| 
    status = record[/^#{pmc.display_name} ((matches|differs).*?\n)(\w|\Z)/m, 1]
    changes[pmc.display_name] = {
      established: record[/^#{pmc.display_name} (established \d+-\d+-\d+)/, 1],
      status: status && status[/^\w.*/],
      detail: status && status.scan(/^\t.*/).map(&:strip)
    }
  end

  _json { _! changes }
end

post '/json/:file' do
  _json :"json/#{params[:file]}"
end
