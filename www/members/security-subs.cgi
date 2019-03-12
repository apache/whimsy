#!/usr/bin/env ruby
$LOAD_PATH.unshift '/srv/whimsy/lib'
require 'wunderbar/bootstrap'
require 'whimsy/asf'
require 'whimsy/asf/mlist'

WHITELIST = [
  /^archive-asf-private@cust-asf\.ponee\.io$/,
  /^private@mbox-vm\.apache\.org$/,
  /^security-archive@.*\.apache\.org$/,
  /^apmail-\w+-security-archive@www.apache.org/, # Direct subscription
]

# ensure that there is a trailing slash (so relative paths will work)
if not ENV['PATH_INFO']
  print "Status: 302 Found\r\nLocation: #{ENV['SCRIPT_URI']}/\r\n\r\n"
  exit
end

# extract information for all security@pmc.apache.org lists
lists = {}
ASF::MLIST.list_parse('sub') do |dom, list, subs|
  next unless list == 'security'
  next unless dom.end_with? '.apache.org'
  lists[dom.sub('.apache.org', '')] = subs
end

_html do
  _whimsy_body(
    title: "Security Mailing List Subscriptions"
  ) do
    path = ENV['PATH_INFO'].sub('/', '')
    if path == ''
      _table.table.table_responsive do
        _tr do
          _th.text_right.col_xs_1 'count'
          _th 'project'
        end
        lists.each do |dom, subs|
          _tr do
            _td.text_right subs.length
            _td do
              _a dom, href: dom
            end
          end
        end
      end

    elsif lists[path]
      podling = ASF::Podling.find(path)
      committee = ASF::Committee.find(path)
      project = ASF::Project.find(path)
      colors=Hash.new{|h,k| h[k]=0} # counts of colors
      order=['bg-danger', 'bg-warning', 'bg-info', 'bg-success', ''] # sort order
      subh = Hash[
        lists[path].map do |email|
          name = '*UNKNOWN*'
          if WHITELIST.any? {|regex| email =~ regex}
            person = nil
            name = '(archiver)'
            color = ''
          else
            person = ASF::Person.find_by_email(email)
            if person
              name = person.public_name
              if person.asf_member? or project.owners.include? person
                color = 'bg-success'
              elsif project.members.include? person
                color = 'bg-info'
              else
                color = 'bg-warning'
              end
            else
              color = 'bg-danger'
            end
          end
          colors[color] += 1
          [email, {person: person , color: color, name: name}]
        end
      ].sort_by {|k,v| [order.index(v[:color]),v[:name]]}
      
      _table do
        _tr do
          _th 'Count '
          _th 'Legend'
        end
        _tr do
          _td colors['bg-danger']
          _td class: 'bg-danger' do
            _ 'Person (email) not recognised'
          end
        end
        _tr do
          _td colors['bg-warning']
          _td class: 'bg-warning' do
            _ 'ASF committer not associated with the project'
          end
        end
        _tr do
          _td colors['bg-info']
          _td class: 'bg-info' do
            _ 'Project committer - not on (P)PMC'
          end
        end
        _tr do
          _td colors['bg-success']
          _td class: 'bg-success' do
            _ 'ASF member or project member'
          end
        end
        _tr do
          _td colors['']
          _td do
            _ 'Archiver (there are expected to be up to 3 archivers)'
          end
        end
      end
      _h2 do
        if podling
          _a podling.display_name, 
            href: "../../roster/ppmc/#{podling.id}"
        else
          _a committee.display_name, 
            href: "../../roster/committee/#{committee.id}"
        end
      end

      _table.table do
        _thead do
          _tr do
            _th 'email'
            _th 'person'
          end
        end

        _tbody do
          subh.each do |email, hash|
            color = hash[:color]
            person = hash[:person]
            name = hash[:name]

            _tr class: color do
              _td email
              _td do
                if person
                  if person.asf_member?
                    _b do
                      _a name, href: "../../roster/committer/#{person.id}"
                    end
                  else
                    _a name, href: "../../roster/committer/#{person.id}"
                  end
                else
                    _ name
                end
              end
            end
          end
        end
      end
    else
      _h3 class: 'bg-warning' do
        _ "Could not find a security list for the project #{path}"
      end
      _br
    end
  end
end
