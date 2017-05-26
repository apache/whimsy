#!/usr/bin/env ruby
PAGETITLE = "Incubator Mailing List Moderators" # Wvisible:incubator mail

$LOAD_PATH.unshift File.realpath(File.expand_path('../../../lib', __FILE__))
require 'wunderbar'
require 'whimsy/asf'
require 'nokogiri'

user = ASF::Person.new($USER)
unless user.asf_member? or ASF::Committee['incubator'].members.include? user
  print "Status: 401 Unauthorized\r\n"
  print "WWW-Authenticate: Basic realm=\"ASF Members and Officers\"\r\n\r\n"
  exit
end

SUBSCRIPTIONS = '/srv/subscriptions/incubator-mods'
PODLINGS = "#{ASF::SVN['asf/incubator/public/trunk/content']}/podlings.xml"

exceptions = {
  "beanvalidation" => "bval",
  "manifoldcf" => "connectors",
  "odftoolkit" => "odf",
  "openofficeorg" => "ooo",
  "zetacomponents" => "zeta"
}

_html do
  _head do
    _title 'Apache Incubator moderators'
    _link rel: "stylesheet", type: 'text/css',
      href: "https://incubator.apache.org/style/bootstrap-1-3-0-min.css"
    _link rel: "stylesheet", type: 'text/css',
      href: "https://incubator.apache.org/style/style.css"
    _style %{
      body { margin: 0 2em }
      p, h3 {margin-left: 2em}
      table {margin-left: 4em}
      hr {margin-top: 1.5em}
    }
  end

  _body? do
    # Standard Incubator header
    _div class: 'container' do
      _div class: 'row' do
        _div class: 'span8' do
          _a href: "https://www.apache.org/" do
            _img alt: "The Apache Software Foundation", border: 0, height: 88,
              src: "https://www.apache.org/img/asf_logo.png"
          end
        end
        _div class: 'span8' do
          _a href: "https://incubator.apache.org/" do
            _img alt: "Apache Incubator", border: 0, height: 88,
              src: "https://incubator.apache.org/images/incubator_feather_egg_logo_sm.png"
          end
        end
      end
      _div class: 'row' do
        _div class: 'span16' do
          _hr noshade: 'noshade', size: '1'
        end
      end
    end

    podlings = Hash[Nokogiri::XML(File.read(PODLINGS)).search('podling').
      map {|podling| [podling["resource"], podling["status"]]}]

    _h1 'Apache Incubator moderators'

    moderators = Hash[File.read(SUBSCRIPTIONS).split(/\n\n/).
      map {|stanza| [stanza[/incubator.apache.org\/(.*)\//,1],
      stanza.scan(/^(.*@.*)/).flatten]}]

    _h1 'Index'

    cols = 6
    slice = (podlings.keys.length+cols-1)/cols
    _table do
      (0...slice).each do |i|
        _tr do
          (0...cols).each do |j|
            _td do
              podling = podlings.keys.sort[i+j*slice]
	      anchor = exceptions[podling] || podling
	      if moderators.keys.any? {|list| anchor == list.split('-').first}
	        _a podling, href: "##{anchor}"
              else
	        _indented_text podling
	      end
            end
	  end
	end
      end
    end

    current = nil
    moderators.keys.sort.each do |list|
      next unless list.include? '-'
      podling = list.split('-').first
      unless podling == current
        _hr_ if current
	name = podling if podlings.include? podling
	name ||= exceptions.invert[podling]
	if name
          _h2 id: podling do
	    _a podling, 
	      href: "https://incubator.apache.org/projects/#{name}.html"
	  end
	else
          _h2 podling, id: podling
	end
        _p "Podling Status: #{podlings[name] || 'unknown'}"
        current = podling
      end

      _h3_ list.sub(podling, '')

      _table do
        moderators[list].sort.each do |moderator|
          person = ASF::Person.find_by_email(moderator)
	  _tr_ do
            if person and person.id != 'notinavail'
              _td! {_a person.id, href: "/roster/committer/#{person.id}"}
              if person.asf_member?
                if person.asf_member? == true
                  _td! {_b person.public_name}
                else
                  _td! {_em person.public_name}
                end
              else
                _td person.public_name
              end
            else
              _td
              _td! {_em 'unknown'}
            end
	    _td moderator
	  end
        end
      end
    end
  end
end
