#!/usr/bin/env ruby
PAGETITLE = "Projects which graduated from the incubator" # Wvisible:incubator

$LOAD_PATH.unshift '/srv/whimsy/lib'
require 'whimsy/asf'
require 'wunderbar'
require 'wunderbar/bootstrap'

source = '/srv/whimsy/www/board/minutes'
index = File.read("#{source}/index.html")

csection = index[/<h2 id="committee">.*?<h2/m]
creports = csection.scan(/<a .*?<\/a>/)
retired = csection.scan(/<del>.*?<\/del>/m)

creports.sort_by! {|committee| committee[/>(.*?)</, 1].downcase}


_html do
  _body? do
    _whimsy_body(
      title: PAGETITLE,
      related: {
        "/committers/tools" => "Whimsy Tool Listing",
        "https://incubator.apache.org/images/incubator_feather_egg_logo_sm.png" => "Incubator Logo, to show that graphics can appear",
        "https://community.apache.org/" => "Get Community Help",
        "https://github.com/apache/whimsy/blob/master/www#{ENV['SCRIPT_NAME']}" => "See This Source Code"
      },
      helpblock: -> {
        _p! do
          _ 'This script cross-checks Committee Reports from '
          _a 'Board Minutes',
            href: 'https://whimsy.apache.org/board/minutes/'
          _ '  and '
          _a 'committee-info.txt',
            href: 'https://svn.apache.org/repos/private/committers/board/committee-info.txt'
          _ '.'
        end
      }
    ) do

      ASF.init_ldap

      unreported = ASF::Committee.pmcs.map(&:display_name).map(&:downcase)
      incubated = 0

      #
      ### Podling mentors vs IPMC
      #
      _whimsy_panel_table(
        title: "Establish Resolutions from Projects that have reported",
      ) do
        _table.table.table_hover.table_striped do
          _thead_ do
            _tr do
              _th 'Committee'
              _th 'Established'
              _th 'Graduated?'
              _th 'Active?'
            end
          end
          _tbody do
            creports.map do |committee|
              name = committee[/>(.*?)</, 1]
              href = committee[/href="(.*?)"/, 1].untaint
              page = File.read("#{source}/#{href}").
                sub(/<footer.*<\/footer>/m, '')

              active = unreported.delete(name.downcase)

              graduated = false

              establish = page.split('<h2').map { |report|
                title = report[/<h3.*?<\/h3>/]
                next unless title and title.downcase.include? 'establish'
                graduated ||= report.downcase.include? 'incubator'
                report[/id="(.*?)"/, 1]
              }.compact.first

              incubated += 1 if graduated

              _tr_ do
                _td do
                  _a name, href: "../board/minutes/#{href}"
                end
                _td do
                  _a establish, href: "../board/minutes/#{href}##{establish}"
                end
                _td graduated
                _td !!active
              end
            end
          end
        end
      end

      _whimsy_panel_table(
        title: "Projects that don't have posted reports"
      ) do
        _table.table.table_hover.table_striped do
          _thead_ do
            _tr do
              _th 'Committee'
            end
          end
          _tbody do
            unreported.each do |committee|
              _tr do
                _td do
                  _a committee, href: "../roster/committee/" +
                    ASF::Committee.find(committee).name
                end
              end
            end
          end
        end
      end unless unreported.empty?

      _whimsy_panel_table(
        title: "Projects summary"
      ) do
        _table.table.table_hover.table_striped id: 'summary' do
          _tbody do
            _tr do
              _td creports.length
              _td "Committees that have reported"
            end

            _tr do
              _td ASF::Committee.pmcs.length
              _td "Active Committees"
            end

            _tr do
              _td retired.length
              _td "Committees that have retired"
            end

            _tr do
              _td incubated
              _td "Graduated from the incubator"
            end
          end
        end
      end
        
    end
  end
end
