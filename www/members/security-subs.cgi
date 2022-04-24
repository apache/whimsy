#!/usr/bin/env ruby
$LOAD_PATH.unshift '/srv/whimsy/lib'
require 'wunderbar/bootstrap'
require 'whimsy/asf'
require 'whimsy/asf/mlist'

NOSUBSCRIBERS = 'No subscribers'
MINSUB = 3
TOOFEW = "Not enough subscribers (< #{MINSUB})"

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
  unknown = 0
  ids = Hash.new(0) # currently used as a set
  sub_hash = subs.map do |sub|
    person = nil # unknown
    if ASF::MLIST.is_private_archiver? sub
      person = ''
    else
      person = ASF::Person.find_by_email(sub)
      if person
        ids[person.name] += 1
      else
        unknown += 1
      end
    end
    [sub, person]
  end.to_h
  lists[dom.sub('.apache.org', '')] =
    {subCount: unknown + ids.size, subscribers: sub_hash}
end

_html do
  _whimsy_body(
    title: "Security Mailing List Subscriptions",
    breadcrumbs: { # N.B. allow for trailing / (see redirect above)
      members: '..',
      subscriptions: '.'
    }

  ) do
    path = ENV['PATH_INFO'].sub('/', '')
    if path == ''
      _p do
        _ 'The counts below exclude the archivers (and duplicate subscriptions), using the highlights: '
        _span.bg_danger NOSUBSCRIBERS
        _span.bg_warning TOOFEW
      end
      _table.table.table_responsive do
        _tr do
          _th.col_xs_1.text_right 'count'
          _th.col_xs_3 'project'
          _th.col_xs_1.text_right 'count'
          _th.col_xs_3 'project'
          _th.col_xs_1.text_right 'count'
          _th.col_xs_3 'project'
          # cols must add up to twelve
        end
        lists.each_slice(3) do |slice|
          _tr do
            slice.each do |dom, subs|
              subcount = subs[:subCount]
              options = {}
              if subcount == 0
                options = {class: 'bg-danger', title: NOSUBSCRIBERS}
              elsif subcount < MINSUB
                options = {class: 'bg-warning', title: TOOFEW}
              end
              _td.text_right options do
                _ subcount
              end
              _td do
                _a dom, href: dom
              end
            end
          end
        end
      end

    elsif lists[path]
      podling = ASF::Podling.find(path)
      committee = ASF::Committee.find(path)
      project = ASF::Project.find(path)
      colors=Hash.new{|h,k| h[k]=Array.new} # ids for each color
      subh = {}
      lists[path][:subscribers].map do |email, person|
        key = nil # hash key, used to collect aggregate emails
        if person == ''
          person = nil
          name = '(archiver)'
          color = ''
          key = name
        else
          if person
            name = person.public_name
            if person.asf_member? or project.owners.include? person
              color = 'bg-success'
            elsif project.members.include? person
              color = 'bg-info'
            else
              color = 'bg-warning'
            end
            key = person.name # availid is unique to person
          else
            color = 'bg-danger'
            name = '*UNKNOWN*'
            key = email
          end
        end
        colors[color] << person&.name || ''
        if subh[key]
          subh[key][:emails] << email
        else
          subh[key] = {person: person , color: color, name: name, emails: [email]}
        end
      end

      _table do
        _tr do
          _th 'Count '
          _th 'Legend'
        end
        _tr do
          _td colors['bg-danger'].size
          _td class: 'bg-danger' do
            _ 'Person (email) not recognised'
          end
        end
        _tr do
          _td colors['bg-warning'].uniq.size
          _td class: 'bg-warning' do
            _ 'ASF committer not associated with the project'
          end
        end
        _tr do
          _td colors['bg-info'].uniq.size
          _td class: 'bg-info' do
            _ 'Project committer - not on (P)PMC'
          end
        end
        _tr do
          _td colors['bg-success'].uniq.size
          _td class: 'bg-success' do
            _ 'ASF member or project member'
          end
        end
        _tr do
          _td colors[''].size
          _td do
            _ 'Archiver (there are expected to be up to 3 archivers)'
          end
        end
      end
      _h2 do
        if podling && podling.status == 'current'
          _a podling.display_name,
            href: "../../roster/ppmc/#{podling.id}"
        else
          _a committee.display_name,
            href: "../../roster/committee/#{committee.id}"
        end
        _span class: 'small' do
          _a "(security@#{path}.apache.org)", href: "https://lists.apache.org/list.html?security@#{path}.apache.org"
        end
      end

      _table.table do
        _thead do
          _tr do
            _th 'email(s)'
            _th 'person (subscription count)'
          end
        end

        _tbody do
          order=['bg-danger', 'bg-warning', 'bg-info', 'bg-success', ''] # sort order
          subh.sort_by {|k,v| [order.index(v[:color]),v[:name]]}.each do |key, hash|
            color = hash[:color]
            person = hash[:person]
            name = hash[:name]
            emails = hash[:emails]

            _tr class: color do
              _td emails.join(', ')
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
                if emails.size > 1
                  _ " (#{emails.size})"
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
