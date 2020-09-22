#!/usr/bin/env ruby
PAGETITLE = "Listing of Apache Trademarks" # Wvisible:brand,trademarks

# return output in JSON format if the query string includes 'json'
ENV['HTTP_ACCEPT'] = 'application/json' if ENV['QUERY_STRING'].include? 'json'

$LOAD_PATH.unshift '/srv/whimsy/lib'
require 'csv'
require 'json'
require 'whimsy/asf'
require 'wunderbar'
require 'wunderbar/bootstrap'
require 'wunderbar/jquery'
require 'net/http'

# Fieldnames/values from counsel provided docket.csv
MNAM = 'TrademarkName'
COUNTRY = 'CountryName'
STAT = 'TrademarkStatus'
CLASS = 'Class'
REG = 'RegNumber'
APPNUMBER = 'AppNumber'
CLASSGOODS = 'ClassGoods'
REGISTERED = 'Registered'
USA = 'United States of America'

UNREG_ID = 'unreg_'
MAP_PMC_REG = {
  'lucene' => 'lucene-core'
}

# Transform docket spreadsheet into structured JSON
def csv2json
  brand_dir = ASF::SVN['brandlist']
  csv = CSV.read("#{brand_dir}/docket.csv", headers:true)
  docket = {}
  csv.each do |r|
    r << ['pmc', r[MNAM].downcase.sub('.org','').sub(' & design','')]
    key = r['pmc'].to_sym
    mrk = {}
    %W[ #{STAT} #{COUNTRY} #{CLASS} #{APPNUMBER} #{REG} #{CLASSGOODS} ].each do |col|
      mrk[col] = r[col]
    end
    if not docket.key?(key)
      docket[key] = { r[MNAM] => [mrk] }
    else
      if not (docket[key]).key?(r[MNAM])
        docket[key][r[MNAM]] = [mrk]
      else
        docket[key][r[MNAM]] << mrk
      end
    end
  end

  docket
end

# Since the CSV changes rarely, it is manually checked in separately
_json do
  csv2json
end

def _unreg(pmc, proj, parent, n)
  _div!.panel.panel_default  id: pmc do
    _div!.panel_heading role: "tab", id: "#{parent}h#{n}" do
      _h4!.panel_title do
        _a!.collapsed role: "button", data_toggle: "collapse",  aria_expanded: "false", data_parent: "##{parent}", href: "##{parent}c#{n}", aria_controls: "#{parent}c#{n}" do
          _! proj['name']
          _{"&trade; software"}
        end
      end
    end
    _div!.panel_collapse.collapse id: "#{parent}c#{n}", role: "tabpanel", aria_labelledby: "#{parent}h#{n}" do
      _div!.panel_body do
        _a! href: proj['homepage'] do
          _! "#{proj['name']}: "
        end
        _! proj['description']
      end
    end
  end
end

def _marks(marks)
  marks.each do |mark, items|
    _ul.list_group do
      _li!.list_group_item.active do
        _{"#{mark} &reg;"}
      end
      items.each do |itm|
        if itm[STAT] == REGISTERED then
          if itm[COUNTRY] == USA then
            _li.list_group_item do
              _a! "In the #{itm[COUNTRY]}, class #{itm[CLASS]}, reg # #{itm[REG]}", href: "https://tsdr.uspto.gov/#caseNumber=#{itm[REG]}&caseSearchType=US_APPLICATION&caseType=DEFAULT&searchType=statusSearch"
            end
          else
            _li.list_group_item "In #{itm[COUNTRY]}, class #{itm[CLASS]}, reg # #{itm[REG]}"
          end
        end
      end
    end
  end
end

def _project(pmc, pnam, purl, marks)
  _div.panel.panel_primary id: pmc do
    _div.panel_heading do
      _h3!.panel_title do
        _a! pnam, href: purl
        _{"&reg; software"}
      end
    end
    _div.panel_body do
      allr = true # If any are not Registered, just say "or applied for..."; ignore other status details
      marks.each do |mark, items|
        if items.any? {|itm| itm[STAT] != REGISTERED }
          allr = allr & false
        end
      end
      if allr
        _{"The ASF owns the following registered trademarks for our #{pnam}&reg; software:"}
      else
        _{"The ASF owns the following registered or applied for trademarks for our #{pnam}&reg; software:"}
      end
    end
    _marks marks
  end
end

def _apache(marks)
  _div.panel.panel_primary id: 'apache' do
    _div.panel_heading do
      _h3.panel_title do
        _{"Our APACHE&reg; trademarks"}
      end
    end
    _div!.panel_body do
      _{"Our APACHE&reg; trademark represents our house brand of consensus-driven, community built software for the public good."}
    end
    _marks marks
  end
end

_html do
  _body? do
    _whimsy_body(
      title: PAGETITLE,
      related: {
        "https://www.apache.org/foundation/marks/resources" => "Trademark Site Map",
        "https://www.apache.org/foundation/marks/list/" => "Official Apache Trademark List",
        "https://www.apache.org/foundation/marks/contact" => "Contact Us About Trademarks"
      },
      helpblock: -> {
        _p "This is an automated listing of the trademarks claimed by the ASF on behalf of our many project communities."
        _p do
          _ 'See the list of '
          _a 'Registered trademarks', href: '#registered'
          _ ' or see other trademarks by letter: '
          end
          _ul.list_inline do
            ("A".."Z").each do |ltr|
              _li do
                _a ltr, href: "##{UNREG_ID}#{ltr.downcase}"
              end
            end
        end
      }
    ) do
      brand_dir = ASF::SVN['brandlist']
      docket = JSON.parse(File.read("#{brand_dir}/docket.json"))
      projects = JSON.parse(Net::HTTP.get(URI('https://projects.apache.org/json/foundation/projects.json')))
      _h3 'The ASF holds the following registered trademarks:', id: 'registered'
      docket.each do |proj, marks|
        # Map project name to name in projects.json for unusual cases
        MAP_PMC_REG.key?(proj) ? pmc = MAP_PMC_REG[proj] :  pmc = proj
        if pmc == 'apache' then
          _apache(marks)
        elsif projects.key?(pmc) then
          _project pmc, projects[pmc]['name'], projects[pmc]['homepage'], marks
        else
          # TODO map all pmc names to projects or podlings
          _project pmc.downcase, 'Apache ' + pmc.capitalize, 'https://' + pmc + '.apache.org', marks
        end
      end
      _h3 'The ASF holds the following unregistered trademarks:'
      allproj = projects.group_by { |k, v| /Apache\s+(.)/.match(v['name'])[1].downcase }
      allproj.sort.each do |ltr, parr|
        parent = "#{UNREG_ID}#{ltr}"
        _div.panel_group id: parent, role: "tablist", aria_multiselectable: "true" do
          parr.each_with_index do |x, num|
            unless docket[x[0]] then
              _unreg(x[0], x[1], parent, num)
            end
          end
        end
      end
    end
  end
end
