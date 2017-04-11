#!/usr/bin/env ruby
$LOAD_PATH.unshift File.realpath(File.expand_path('../../../lib', __FILE__))
require 'csv'
require 'json'
require 'whimsy/asf'
require 'wunderbar'
require 'wunderbar/bootstrap'
require 'net/http'
require 'whimsy/asf/themes'

PAGETITLE = 'Listing of Apache Registered Trademarks'

_html do
  _head_ do
    _title PAGETITLE
    _style %{
      th {border-bottom: solid black}
      table {border-spacing: 1em 0.2em }
      tr td:first-child {text-align: center}
      .issue {color: red; font-weight: bold}
    }
  end
  _body? do
    _whimsy_header PAGETITLE
    brand_dir = ASF::SVN['private/foundation/Brand']
    docket = CSV.read("#{brand_dir}/trademark-registrations.csv", headers:true)
    docketcols = %w[ Mark Jurisdiction Class ] 
    # TODO: consolidate Jurisdiction info by 'Mark' column  
    # TODO: add optional json output to convert rarely-changed registered CSV into checkinable JSON
    projects = JSON.parse(Net::HTTP.get(URI('https://projects.apache.org/json/foundation/projects.json')))
    _whimsy_content do
      _table class: "table " do
        _thead_ do
          _tr do
            docketcols.each { |h| _th h }
          end
        end
        _tbody do
          docket.each do | row |
            _tr_ do
              docketcols.each do |h|
                if h == 'Mark' then
                  _td do
                    begin
                      # TODO: Map unusual project names
                      _a row[h], href: projects[row[h].downcase]['homepage']
                    rescue 
                      _ row[h]
                    end
                  end
                else 
                  _td row[h]
                end
              end
            end
          end
        end
      end
    end
    _whimsy_footer({
      "https://www.apache.org/foundation/marks/resources" => "Trademark Site Map",
      "https://www.apache.org/foundation/marks/list/" => "Official Apache Trademark List"
      })
  end
end
