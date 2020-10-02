#!/usr/bin/env ruby


### INITIAL RELEASE - SUBJECT TO CHANGE ###


$LOAD_PATH.unshift '/srv/whimsy/lib'


require 'whimsy/asf'
require 'whimsy/asf/memapps'
require 'wunderbar'
require 'yaml'

file = File.join(ASF::SVN.find!('emeritus-involuntary'),'emeritus-involuntary.yml')
forced = Set.new
YAML.load_file(file).each{|k,v| v.each{|w| forced.add w}}

exmembers = ASF::Member.emeritus.map {|id| ASF::Person.find(id)}
ASF::Person.preload(['cn'], exmembers) # speed up
files = Hash[ASF::EmeritusFiles::listnames.map{|i| [i,'NAK']}]
nofiles = Hash.new()

exmembers.each { |m|
  ma = ASF::EmeritusFiles.find(m)
  if ma
    files[ma] = 'OK'
  else
    nofiles[m.name]=m
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

  _h1 'Compare members.txt with emeritus (**DRAFT**)'

  _h2 'Files in emeritus that do not match any ASF member names'

  _table_ do
    _tr do
      _th 'Name'
    end
    files.select {|k,v| v == 'NAK'}.sort_by{|k| k[0].split('-').pop}.each do |k,v|
      _tr do
        _td do
          _a k, href: ASF::SVN.svnpath!('emeritus', k), target: '_blank'
        end
      end
    end
  end

_h2 'Emeritus entries in members.txt which do not appear to have a matching emeritus file'
_table_ do
  _tr do
    _th 'Availid'
    _th 'ICLA'
    _th 'Public Name'
    _th 'Legal Name'
    _th 'Member.txt Name'
  end
  nofiles.sort_by{|k,v| v.member_name}.each do |k,v|
    person = v
    if forced.delete? person.member_name
      next
    end
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
    end
  end
end

  if forced.size > 0
    _h2 'Files in emeritus-involuntary.yml that do not match any ASF emeritus member names'
    _ul do
      forced.each do |n|
        _li n
      end
    end
  end

end
