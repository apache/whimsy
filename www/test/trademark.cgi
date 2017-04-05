#!/usr/bin/env ruby
$LOAD_PATH.unshift File.realpath(File.expand_path('../../../lib', __FILE__))
require 'csv'
require 'json'
require 'whimsy/asf'
require 'wunderbar'
require 'wunderbar/bootstrap'
require 'net/http'

# Adding consistent Whimsy styles TODO: document and move to lib/asf
class Wunderbar::HtmlMarkup
  def _whimsy_header style, title
    case style
    when :fullsize
      _div.header do
        _a href: 'https://whimsy.apache.org/' do
          _img title: "ASF Logo", alt: "ASF Logo",
          src: "https://www.apache.org/img/asf_logo.png"
        end
        _a href: '/' do
          _img title: "Whimsy logo", alt: "Whimsy hat", src: "../whimsy.svg", width: "140" 
        end
        _h1 title
      end
    else
      _a href: 'https://whimsy.apache.org/' do
        _img title: "ASF Logo", alt: "ASF Logo",
        src: "https://www.apache.org/img/asf_logo.png"
      end
      _h2 title
    end
  end
end

PAGETITLE = 'Listing of Apache Registered Trademarks'

brand_dir = ASF::SVN['private/foundation/Brand']
docket = CSV.read("#{brand_dir}/trademark-registrations.csv", headers:true)
docketcols = %w[ Mark Jurisdiction Class ] 
# TODO: consolidate Jurisdiction info by 'Mark' column

# TODO add error recovery
projects = JSON.parse(Net::HTTP.get(URI('https://projects.apache.org/json/foundation/projects.json')))

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
    _whimsy_header :fullsize, PAGETITLE
    _table do
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
    
    _div.footer do  
      _h2_ 'Apache Trademark Resources'
      _ul do
        _li do
          _a 'Trademark Site Map', href: 'https://www.apache.org/foundation/marks/resources'
        end
      end
    end
  end
end
