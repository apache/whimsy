#!/usr/bin/env ruby
PAGETITLE = "Apache Org Chart Display" # Wvisible:orgchart
$LOAD_PATH.unshift File.realpath(File.expand_path('../../../lib', __FILE__))
require 'json'
require 'whimsy/asf'
require 'whimsy/asf/orgchart' # New class not yet in gem; duplicates www/roster/models/orgchart
require 'wunderbar'
require 'wunderbar/bootstrap'
OTHER_LINKS = {
  'https://people.apache.org/phonebook.html' => 'Apache Project Rosters Listing',
  'https://incubator.apache.org/projects/#current' => 'Apache Incubator Podling Listing',
  'https://people.apache.org/committer-index.html' => 'Apache Individual Committer Listing',
  'https://www.apache.org/foundation/members' => 'Social Listing Of ASF Members'
}

# Output the orgchart overview
def emit_orgchart(org: {})
  _whimsy_panel_table(
  title: "Apache Corporate Organization Chart",
  helpblock: -> {
    _ 'This is a listing of most '
    _em 'corporate'
    _ ' officers and roles at the ASF. This does '
    _strong 'not'
    _ ' include the VP of each Apache PMC that provide software products.' 
  }
  ) do
    _table.table.table_striped do
      _thead do
        _th 'Title'
        _th 'Contact, Chair, or Person holding that title'
        _th 'Public Website'
      end
      _tbody do
        org.sort_by {|key, value| value['info']['role']}.each do |key, value|
          _tr_ do
            _td do
              _a value['info']['role'], href: "orgchart/#{key}"
            end
            _td do
              id = value['info']['id'] || value['info']['chair']
              __ ASF::Person.find(id).public_name
            end
            _td do
              value['info']['website'].nil? ? _('')  : _a('website', href: value['info']['website'])
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
  _whimsy_panel_table(
  title: "#{role['info']['role']} - #{ASF::Person.find(id).public_name}",
  ) do
    _table.table.table_striped do
      _tbody do
        role['info'].each do |key, value|
          next if key == 'role'
          next if key == 'roster' # No purpose in public display
          next if key =~ /private/i
          next unless value
          _tr_ do
            _td key
            if %w(id chair).include? key
              _td do
                if value == 'tbd'
                  _span value
                else
                  _a value, href: "roster/#{value}"
                end
              end
            elsif %w(reports-to).include? key
              _td! do
                value.split(/[, ]+/).each_with_index do |role_inner, index|
                  _span ', ' if index > 0
                  if role_inner == 'members'
                    _a role_inner, href: "roster/members"
                  else
                    _a role_inner, href: "orgchart/#{role_inner}"
                  end
                end
              end
            elsif %w(email).include? key
              _td do
                _a value, href: "mailto:#{value}"
              end
            elsif %w(roster resolution).include? key
              _td do
                _a value, href: value
              end
            else
              _td value
            end
            _td do
              _(desc[key]) if desc.key?(key)
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
        oversees.each do |name, duties|
          _li.list_group_item do
            _a duties['info']['role'], href: "orgchart/#{name}"
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
          _p text
        end
      end
    end
  end
end

_html do
  _body? do
    _whimsy_body(
    title: PAGETITLE,
    related: {
      "https://www.apache.org/foundation/governance/orgchart" => "Graphical Org Chart",
      "https://www.apache.org/foundation" => "Official ASF Officer Listing",
      "https://www.apache.org/foundation/governance/" => "Corporate Governance At The ASF"
    },
    helpblock: -> {
      _p "ALPHA1 - NOT IMPLEMENTED YET"
      _p "This is a sample implementation of a public orgchart, copying part of the features of /roster tool."
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
      if request =~ /orgchart\/?\z/
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
            _a 'Go back to the orgchart', href: ENV['SCRIPT_NAME']
          end
        end
      else
        _p "DEBUG: You are running this script from the command line."
      end
    end
  end
end
