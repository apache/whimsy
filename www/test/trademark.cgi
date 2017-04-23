#!/usr/bin/env ruby
$LOAD_PATH.unshift File.realpath(File.expand_path('../../../lib', __FILE__))
require 'csv'
require 'json'
require 'whimsy/asf'
require 'wunderbar'
require 'wunderbar/bootstrap'
require 'net/http'

PAGETITLE = 'Listing of Apache Registered Trademarks'
COUNTRY = 'CountryName' # Fieldnames from counsel provided docket
STAT = 'TrademarkStatus'
CLASS = 'Class'
REG = 'RegNumber'

def _marks(marks)
  _ul.list_group do
    marks.each do |mark, items|
      _li!.list_group_item.active do
        _{"#{mark} &reg;"}
      end
      items.each do |itm|
        if itm[STAT] == 'Registered' then
          if itm[COUNTRY] == 'United States of America' then
            _li.list_group_item do
              _a "In the #{itm[COUNTRY]}, class #{itm[CLASS]}, reg # #{itm[REG]}", href: 'usptolink'
            end
          else
            _li.list_group_item "In the #{itm[COUNTRY]}, class #{itm[CLASS]}, reg # #{itm[REG]}", href: 'usptolink'
          end
        end
      end
    end
  end
end

def _project(name, url, marks)
  _div.panel.panel_primary do
    _div.panel_heading do 
      _h3!.panel_title do 
        _a! name, href: url
        _{"&reg; software"}
      end
    end
    _div.panel_body do
      _{"The ASF owns the following registered trademarks for our #{name}&reg; software:"}
    end
    _marks marks
  end
end

def _apache(marks)
  _div.panel.panel_primary do
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
    _whimsy_header PAGETITLE
    brand_dir = ASF::SVN['private/foundation/Brand']
    docket = JSON.parse(File.read("#{brand_dir}/docket.json"))
    projects = JSON.parse(Net::HTTP.get(URI('https://projects.apache.org/json/foundation/projects.json')))

    _whimsy_content do
      _p 'The ASF holds the following registered trademarks'
      docket.each do |pmc, marks|
        if pmc == 'apache' then
          _apache(marks)
        elsif projects[pmc] then
          _project projects[pmc]['name'], projects[pmc]['homepage'], marks
        else
          _.comment! '# TODO map all pmc names to projects or podlings'
          _project 'Apache ' + pmc.capitalize, 'https://' + pmc + '.apache.org', marks
        end
      end
    end

    _whimsy_footer({
      "https://www.apache.org/foundation/marks/resources" => "Trademark Site Map",
      "https://www.apache.org/foundation/marks/list/" => "Official Apache Trademark List"
      })
  end
end
