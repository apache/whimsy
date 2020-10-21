#!/usr/bin/env ruby
PAGETITLE = "Apache Corporate Organization Chart" # Wvisible:orgchart
$LOAD_PATH.unshift '/srv/whimsy/lib'
require 'json'
require 'whimsy/asf'
require 'whimsy/asf/orgchart'
require 'wunderbar'
require 'wunderbar/bootstrap'
require 'wunderbar/markdown'
OTHER_LINKS = {
  'https://people.apache.org/phonebook.html' => 'Apache Project Rosters Listing',
  'https://incubator.apache.org/projects/#current' => 'Apache Incubator Podling Listing',
  'https://people.apache.org/committer-index.html' => 'Apache Individual Committer Listing',
  'https://www.apache.org/foundation/members' => 'Social Listing Of ASF Members'
}
URLROOT = '/foundation/orgchart'

# Output the orgchart overview
def emit_orgchart(org: {})
  _whimsy_panel_table(
  title: 'Apache Corporate Organization Chart',
  helpblock: -> {
    _ 'This is a listing of most '
    _em 'corporate'
    _ ' officers and roles at the ASF. This does '
    _strong 'not'
    _ ' include the many Apache '
    _em 'Project'
    _ ' VPs that help build Apache software products in our communities.'
  }
  ) do
    _table.table.table_striped do
      _thead do
        _th 'Title / Role'
        _th 'Contact, Chair, or Person holding that title'
        _th 'Website'
      end
      _tbody do
        org.sort_by {|key, value| value['info']['role']}.each do |key, value|
          _tr_ do
            _td do
              _a value['info']['role'], href: "#{URLROOT}/#{key}"
            end
            _td do
              id = value['info']['id'] || value['info']['chair']
              tmp = ASF::Person[id]
              if tmp.nil?
                _em id
              else
                _ tmp.public_name
              end
            end
            _td do
              web = value['info']['website']
              web.nil? ? _('')  : _a(web.sub(%r{http(s)?://}, ''), href: web)
            end
          end
        end
      end
    end
  end
end

# Output one role's duties and data
def emit_role(role: {}, oversees: {}, desc: {})
  id = role['info']['id'] || role['info']['chair']
  tmp = ASF::Person[id]
  if tmp.nil?
    idnam = id
  else
    idnam = tmp.public_name
  end
  _ol.breadcrumb do
    _li do
      _a 'OrgChart', href: URLROOT
    end
    _li.active do
      _ role['info']['role']
    end
  end
  _whimsy_panel_table(
  title: "#{role['info']['role']} - #{idnam}",
  ) do
    _table.table.table_striped do
      _tbody do
        role['info'].each do |k, value|
          key = k.downcase # Prevent case mismatches
          next if key == 'role'
          next if key == 'roster' # No purpose in public display yet
          next if key =~ /private/i
          next unless value
          _tr_ do
            # Different output than www/roster/orgchart
            _td do
              _(desc[key]) if desc.key?(key)
            end
            if %w(id chair).include? key
              _td do
                if tmp.nil?
                  _em idnam
                else
                  _ idnam
                end
              end
            elsif %w(reports-to).include? key
              _td! do
                value.split(/[, ]+/).each_with_index do |role_inner, index|
                  _span ', ' if index > 0
                  if role_inner == 'members'
                    _a 'Apache Membership', href: 'https://www.apache.org/foundation/members'
                  else
                    _a role_inner, href: "#{URLROOT}/#{role_inner}"
                  end
                end
              end
            elsif %w(email).include? key
              _td do
                _a value, href: "mailto:#{value}"
              end
            elsif %w(resolution website).include? key
              _td do
                _a value, href: value
              end
            else
              _td value
            end
          end
        end
      end
    end
    unless oversees.empty?
      oversees = oversees.sort_by {|name, duties| duties['info']['role']}
      _ul.list_group do
        _li.list_group_item.active do
          _h4 'This Officer Oversees'
        end
        _li.list_unstyled do
          _ul style: 'margin-top: 15px; margin-bottom: 15px;' do
            oversees.each do |name, duties|
              _li do
                _a duties['info']['role'], href: "#{URLROOT}/#{name}"
              end
            end
          end
        end
      end
    end
    _ul.list_group do
      role.each do |title, text|
        next if title == 'info' or title == 'mtime'
        next if title =~ /private/i
        _li.list_group_item.active do
          _h4 title.capitalize
        end
        _li.list_group_item do
          _markdown text
        end
      end
    end
  end
end

_html do
  _body? do
    _whimsy_body(
    title: PAGETITLE,
    relatedtitle: 'More About ASF Operations',
    related: {
      "https://www.apache.org/foundation/governance/orgchart" => "Graphical Org Chart",
      "https://www.apache.org/foundation" => "Official ASF Officer Listing",
      "https://www.apache.org/foundation/governance/" => "Corporate Governance At The ASF"
    },
    helpblock: -> {
      _p "The ASF is a 501C3 non-profit corporation in the US - and there's a lot going on the corporate side of the ASF, to keep the corporate records and infrastructure that the many Apache projects you use working."
      _p "Below is a listing of the officers and people who make the corporate side of the ASF work.  Here are a few more links that explain how corporate governance works at the ASF, which is separate from how Apache PMCs work."
      _ul do
        OTHER_LINKS.each do |url, desc|
          _li do
            _a desc, href: url
          end
        end
      end
    }
    ) do
      request = ENV['REQUEST_URI']
      if request =~ /orgchart\/?\z/ || request == '/foundation/orgchart.cgi' # as from tools listing
        emit_orgchart(org: ASF::OrgChart.load)
      elsif request =~ /orgchart\/([^\/?#]+)/
        orgchart = ASF::OrgChart.load
        name = $1
        if orgchart.key? name
          oversees = orgchart.select do |role, duties|
            duties['info']['reports-to'].split(/[, ]+/).include? name
          end
          emit_role(role: orgchart[name], oversees: oversees, desc: ASF::OrgChart.desc)
        else
          _whimsy_panel("ERROR: role '#{name}' not found", style: 'panel-danger') do
            _ 'Sorry, the URL you attempted to access '
            _code request
            _ ' is not a valid role.'
            _a 'Go back to the orgchart', href: URLROOT
          end
        end
      else
        _p "DEBUG: You may be running this script from the command line."
        _a 'Go back to the orgchart', href: URLROOT
      end
    end
  end
end
