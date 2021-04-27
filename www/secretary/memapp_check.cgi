#!/usr/bin/env ruby


### INITIAL RELEASE - SUBJECT TO CHANGE ###


$LOAD_PATH.unshift '/srv/whimsy/lib'


require 'whimsy/asf'
require 'whimsy/asf/memapps'
require 'wunderbar'

# Dummy class for members that don't have ids but do have membership apps
class PersonNoId
  attr_reader :member_name
  attr_reader :id # needed for memapps.rb
  def initialize name
    @member_name = name
  end
end
status = ASF::Member.status

members = ASF::Member.new.map {|id, text| ASF::Person.find(id)}

# These members don't have ids, so cannot use the Person class
members << PersonNoId.new("Shane Caraveo")
members << PersonNoId.new("Robert Hartill")
members << PersonNoId.new("Andrew Wilson")

files = Hash[ASF::MemApps.names.map{|i| [i,'NAK']}]
nofiles = Hash.new()

members.each { |m|
  ma, tried = ASF::MemApps.find(m)
  if ma.length > 0
    ma.each {|t| files[t]='OK'}
  else
    nofiles[m.name]=[m,status[m.name],tried]
  end
}
_html do
  _style %{
    table {border-collapse: collapse}
    table, th, td {border: 1px solid black}
    td {padding: 3px 6px}
    tr:hover td {background-color: #FF8}
    th {background-color: #a0ddf0}
  }

  _h1 'Compare members.txt with member_apps (**DRAFT**)'

  _h2 'Files in member_apps that do not match any ASF member names'

  _table_ do
    _tr do
      _th 'Name'
    end
    files.select {|k,v| v == 'NAK'}.sort_by{|k| k[0].split('-').pop}.each do |k,v|
      _tr do
        _td do
          _a k, href: ASF::SVN.svnpath!('member_apps', k), target: '_blank'
        end
      end
    end
  end

_h2 'Entries in members.txt which do not appear to have a matching membership app file'
_table_ do
  _tr do
    _th 'Availid'
    _th 'ICLA'
    _th 'Public Name'
    _th 'Legal Name'
    _th 'Member.txt Name'
    _th 'Status'
  end
  nofiles.sort.each do |k,v|
    person, status, _tried = v
    _tr do
      _td do
        _a k, href: "https://whimsy.apache.org/roster/committer/#{k}", target: '_blank'
      end
      _td do
        if person.icla && person.icla.claRef
          file = ASF::ICLAFiles.match_claRef(person.icla.claRef)
          if file
            _a person.icla.claRef, href: ASF::SVN.svnpath!('iclas', file), target: '_blank'
          else
            _ ''
          end
        else
          _ ''
        end
      end
      _td (person.icla.name rescue '')
      _td (person.icla.legal_name rescue '')
      _td person.member_name
      _td status
    end
  end
end


end
