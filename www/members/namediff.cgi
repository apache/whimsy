#!/usr/bin/env ruby
$LOAD_PATH.unshift File.realpath(File.expand_path('../../../lib', __FILE__))

require 'whimsy/asf'
require 'wunderbar/bootstrap'

people = ASF::ICLA.preload
ldap_members = ASF::Member.list.map {|id, info| ASF::Person.find(id)}
names = ASF::Person.preload('cn', ldap_members)

_html do
  _h1 'ASF Member name differences'

  # common banner
  _a_ href: 'https://whimsy.apache.org/' do
    _img title: "ASF Logo", alt: "ASF Logo",
      src: "https://www.apache.org/img/asf_logo.png"
  end

  _p_ "Cross-check of members.txt vs iclas.txt"

  _table.table.table_hover do
    _thead do
      _tr do
        _th 'availid'
        _th 'name from members.txt'
        _th 'public name'
        _th 'legal name (if different)'
      end
    end

    ASF::Member.list.sort.each do |id, info|
      person = ASF::Person.find(id)

      if person.icla
        next if person.icla.name == info[:name]
        next if person.icla.legal_name == info[:name]
        _tr_ do
          _td id
          _td info[:name]
          _td person.icla.name
          if person.icla.name != person.icla.legal_name
            _td person.icla.legal_name
          else
            _td
          end
        end
      elsif ldap_members.include? person
        _tr_ do
          _td id
          _td info[:name]
          _td.bg_danger 'ICLA not on file', colspan: 2
        end
      end
    end
  end
end
