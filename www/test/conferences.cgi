#!/usr/bin/env ruby
$LOAD_PATH.unshift File.realpath(File.expand_path('../../../lib', __FILE__))
require 'json'
require 'net/http'
require 'wunderbar'
require 'wunderbar/bootstrap'
require 'wunderbar/jquery/stupidtable'
require 'whimsy/asf/themes'

PAGETITLE = 'FOSS Conference Listings'

_html do
  _body? do
    _whimsy_header PAGETITLE
    
    conflist = JSON.parse(Net::HTTP.get(URI('https://raw.githubusercontent.com/afilina/dev-community-data/master/data/conferences.json')))
    _whimsy_content do
      _div.row do
        _div.col_sm_10 do
          _div.panel.panel_primary do
            _div.panel_heading {_h3.panel_title 'FOSS Conference Listings'}
            _div.panel_body do
              _ 'Listing various self-reported FOSS Conferences and their claimed speaker support status.  Data from '
              _a 'afilina/dev-community-data', href: 'https://github.com/afilina/dev-community-data/'
              _ ', calendar website at '
              _a 'ConFoo Community', href: 'https://community.confoo.ca/'
              _ '.  Click to sort table.'
            end
          end
        end
      end
      ct, ticket, hotel, travel = 0, 0, 0, 0
      _div.row do
      _table.table.table_hover do
        _thead_ do
          _tr do
            _th 'Conference', data_sort: 'string'
            _th 'Speaker Pass', data_sort: 'string'
            _th 'Speaker Hotel', data_sort: 'string'
            _th 'Speaker Travel', data_sort: 'string'
            _th 'Last Event', data_sort: 'string'
            _th 'Twitter'
          end
        end
        _tbody do
          conflist.each do | conf |
            ct += 1
            _tr_ do
              _td do 
                _a conf['name'], href: conf['website']
              end
              if conf['speaker_kit'] then
                if conf['speaker_kit']['ticket_included'] then
                  ticket += 1
                end
                if conf['speaker_kit']['hotel_included'] then
                  hotel += 1
                end
                if conf['speaker_kit']['travel_included'] then
                  travel += 1
                end
                _td conf['speaker_kit']['ticket_included']
                _td conf['speaker_kit']['hotel_included']
                _td conf['speaker_kit']['travel_included']              
              else
                _td 'False'
                _td 'False'
                _td 'False'
              end
              _td conf['last_event']
              _td do 
                _a conf['twitter'], href: conf['twitter']
              end
            end
          end
        end
      end
    end
    _p.count do 
      _b "Out of total: #{ct} conferences"
      _ ", ones that cover ticket: #{ticket}, hotel: #{hotel}, travel: #{travel}."
    end
    
    _script %{
      var table = $(".table").stupidtable();
      table.on("aftertablesort", function (event, data) {
        var th = $(this).find("th");
        th.find(".arrow").remove();
        var dir = $.fn.stupidtable.dir;
        var arrow = data.direction === dir.ASC ? "&uarr;" : "&darr;";
        th.eq(data.column).append('<span class="arrow">' + arrow +'</span>');
        });
      }
    _whimsy_footer({
      "https://github.com/afilina/dev-community-data" => "FOSS conference listing",
      "https://www.apache.org/foundation/marks/resources" => "Trademark Site Map",
      "https://www.apache.org/foundation/marks/list/" => "Official Apache Trademark List"
      })
    end
  end
end