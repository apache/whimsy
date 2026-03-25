#!/usr/bin/env ruby


### INITIAL RELEASE - SUBJECT TO CHANGE ###


$LOAD_PATH.unshift '/srv/whimsy/lib'


require 'whimsy/asf'
require 'whimsy/asf/memapps'
require 'wunderbar'
require 'yaml'

# get array of emeritus members: [name, availid, first line]
emeritus = ASF::Member.list_entries.select{|x,_y| x == :emeritus}.map{|_,_x,y,z| [y,z[0]]}

exmembers = emeritus.map {|id,_l0| ASF::Person.find(id)}
ASF::Person.preload(['cn'], exmembers) # speed up
files = Hash[ASF::EmeritusFiles::listnames.map{|i| [i,'NAK']}]
nofiles = Hash.new()

ASF::ICLAFiles.update_cache({})

involuntary = emeritus.select{|_id,l0| l0.include?('/* involuntary')}.map{|id,l0| id}
exmembers.each { |m|
  ma = ASF::EmeritusFiles.find(m)
  if ma
    files[ma] = 'OK'
  else
    nofiles[m.name] = m unless involuntary.include?(m.id)
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
    files.select { |_k, v| v == 'NAK'}.sort_by { |k| k[0].split('-').pop}.each do |k, _v|
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
    nofiles.sort_by { |_k, v| v.member_name}.each do |k, person|
      _tr do
        _td do
          _a k, href: "https://whimsy.apache.org/roster/committer/#{k}", target: '_blank'
        end
        _td do
          if person.icla&.claRef
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

end
