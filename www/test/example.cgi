#!/usr/bin/env ruby
PAGETITLE = "Example Whimsy Script With Styles" # Wvisible:tools Note: PAGETITLE must be double quoted

$LOAD_PATH.unshift '/srv/whimsy/lib'
require 'json'
require 'yaml'
require 'wunderbar'
require 'wunderbar/bootstrap'
require 'wunderbar/jquery'
require 'wunderbar/markdown'
require 'whimsy/asf'
require 'whimsy/public'

# Get data from live whimsy.a.o/public directory
def get_public_data()
  return Public.getJSON('public_ldap_authgroups.json')
end

# Get data from a Subversion directory
# See /repository.yml for list of auto-updated dirs
def get_svn_data()
  dir = ASF::SVN['comdevtalks']
  filename = 'README.yaml'
  data = YAML.load(File.read(File.join(dir, filename).untaint))
  return data['title']
end

# Gather some data beforehand, if you like, but:
# Note runtime errors here just write to the log, not to user's browser
talktitle = get_svn_data()

# Produce HTML
_html do
  _body? do # The ? traps errors inside this block
    _whimsy_body( # This emits the entire page shell: header, navbar, basic styles, footer
      title: PAGETITLE,
      subtitle: 'About This Example Script',
      relatedtitle: 'More Useful Links',
      related: {
        "/committers/tools" => "Whimsy Tool Listing",
        "https://incubator.apache.org/images/incubator_feather_egg_logo_sm.png" => "Incubator Logo, to show that graphics can appear",
        "https://community.apache.org/" => "Get Community Help",
        "https://github.com/apache/whimsy/blob/master/www#{ENV['SCRIPT_NAME']}" => "See This Source Code"
      },
      helpblock: -> {
        _p "This www/test/example.cgi script shows a canonical way to write a simple whimsy tool that processes data and then displays it."
        _p %{
          This helpblock appears at top left, and should explain to an end user what this script does for the user and why they might be interested.
          Any related whimsy or other (projects.a.o, etc.) links should be in the related: listing on the top right to help users find other useful things.
          This provides a consistent user experience.
        }
        _p "You can output data previously processed as well like: #{talktitle}"
      },
      breadcrumbs: {
        dataflow: '/test/dataflow.cgi',
        testscript: '/test/example.cgi'
      }
    ) do
      # IF YOUR SCRIPT EMITS A LARGE TABLE
      _whimsy_panel_table(
        title: "Data Table H2 Title Goes Here",
        helpblock: -> {
          _p "If your script displays a sizeable table(s) of data, then use this area to provide a Key: to the data."
        }
      ) do
        # Gather or process your data **here**, so if an error is raised, the _body? 
        #   scope will trap it - and will then display the above help information 
        #   to the user before emitting a polite error traceback.
        datums = {'one' => 1, 'two' => 2 }
        _table.table.table_hover.table_striped do
          _thead_ do
            _tr do
              _th 'Row Number'
              _th 'Column Two'
            end
            _tbody do
              datums.each do | key, val |
                _tr_ do
                  _td do
                    _ key
                  end
                  _td do
                    _ val
                  end
                end
              end
            end
          end
        end
      end

      # IF YOUR SCRIPT ONLY EMITS SIMPLE DATA
      _h2 "Simple Data Can Just Use A List"
      _ul do
        [1,2,3].each do |row|
          _li "This is row number #{row}."
        end
      end

      # NIFTY ACCORDION EXPAND-O LISTING: the _whimsy_accordion_item does most of the work
      _h2 'Lists of Complex Data Can Use An Accordion'
      accordionid = 'accordion'
      officers = get_public_data()
      _div.panel_group id: accordionid, role: 'tablist', aria_multiselectable: 'true' do
        officers['auth'].each_with_index do |(listname, rosters), n|
          _whimsy_accordion_item(listid: accordionid, itemid: listname, itemtitle: "#{listname}", n: n, itemclass: 'panel-primary') do
            _ul do
              rosters['roster'].each do |usr|
                _li usr
              end
            end
          end
        end
      end
    end
  end
end
