#!/usr/bin/env ruby
$LOAD_PATH.unshift File.realpath(File.expand_path('../../../lib', __FILE__))
require 'json'
require 'net/http'
require 'wunderbar'
require 'wunderbar/bootstrap'
require 'wunderbar/jquery/stupidtable'
require 'whimsy/asf/themes'
require 'date'

PAGETITLE = 'FOSS Conference Listings - DEPRECATED'

_html do
  _body? do
    _whimsy_header PAGETITLE
    
    conflist = JSON.parse(Net::HTTP.get(URI('https://raw.githubusercontent.com/afilina/dev-community-data/master/data/conferences.json')))
    _whimsy_content do
      _p do 
        _ 'THIS PAGE IS DEPRECATED - please see '
        _a '/events/other', href: 'https://whimsy.apache.org/events/other'
        _ 'instead!'
      end
      _div.row do
        _div.col_sm_10 do
          _div.panel.panel_primary do
            _div.panel_heading {_h3.panel_title 'FOSS Conference Listings'}
            _div.panel_body do
              _ 'Listing various self-reported FOSS Conferences and their claimed speaker support status.  Data from '
              _a_ 'afilina/dev-community-data', href: 'https://github.com/afilina/dev-community-data/'
              _ ', calendar website at '
              _a_ 'ConFoo Community', href: 'https://community.confoo.ca/'
              _ '.  Click to sort table.  "False" propercase entries are when conference doesn\'t report any speaker reimbursement details.' 
            end
          end
        end
      end
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
            _tr_ do
              _td do 
                _a conf['name'], href: conf['website']
              end
              if conf['speaker_kit'] then
                _td conf['speaker_kit']['ticket_included']
                _td conf['speaker_kit']['hotel_included']
                _td conf['speaker_kit']['travel_included']              
              else
                _td 'False'
                _td 'False'
                _td 'False'
              end
              if conf['events'] then
                laste = conf['events'].max_by {|e| Date.parse(e['event_end'])}
                _td laste['event_end']
              else
                _td conf['last_event']
              end
              _td do 
                _a conf['twitter'], href: conf['twitter']
              end
            end
          end
        end
      end
    end
    counts = %w(ticket_included hotel_included travel_included).map do |field|
    matches = conflist.select do |conf|
        conf['speaker_kit'] && conf['speaker_kit'][field]
      end

      [field, matches.count]
    end
    counts = counts.to_h
    _p.count do 
      _b "Out of total: #{conflist.count} conferences"
      _ ", number that cover:"
      counts.each do |s, v|
        _ "#{s}: #{v}"
      end
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