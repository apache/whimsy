#!/usr/bin/env ruby
PAGETITLE = "Other FOSS Conference Listings" # Wvisible:events

$LOAD_PATH.unshift File.realpath(File.expand_path('../../../lib', __FILE__))
require 'json'
require 'net/http'
require 'whimsy/asf'
require 'wunderbar'
require 'wunderbar/bootstrap'
require 'wunderbar/jquery/stupidtable'
require 'date'

# TODO format change coming: https://github.com/afilina/dev-community-data/issues/90 
conflist = JSON.parse(Net::HTTP.get(URI('https://raw.githubusercontent.com/afilina/dev-community-data/master/data/conferences.json')))
SPEAKERKIT = 'speaker_kit'
cols = {
  'ticket_included' => 'Speaker Pass',
  'hotel_included' => 'Speaker Hotel',
  'travel_included' => 'Speaker Travel'
}

counts = cols.keys.map do |field|
  matches = conflist.select do |conf|
    conf[SPEAKERKIT] && conf[SPEAKERKIT][field]
  end
  
  [field, matches.count]
end
counts = counts.to_h

_html do
  _body? do
    _whimsy_header PAGETITLE
    _whimsy_content do
      _div.row do
        _div.col_sm_10 do
          _whimsy_panel PAGETITLE do
            _ "Listing #{conflist.count} self-reported FOSS Conferences and their claimed speaker support status.  Data from "
            _a_ 'afilina/dev-community-data', href: 'https://github.com/afilina/dev-community-data/'
            _ ', calendar website at '
            _a_ 'ConFoo Community', href: 'https://community.confoo.ca/'
            _ '.  Click to sort table.  "False" propercase entries are when conference doesn\'t report any speaker reimbursement details.'
            _br
            _p 'Conferences that include speaker benefit types:' 
            _ul do
              counts.each do |s, num|
                _li "#{cols[s]}: #{num}"
              end
            end
          end
        end
      end
      _div.row do
        _table.table.table_hover.table_striped do
          _thead_ do
            _tr do
              _th 'Conference', data_sort: 'string'
              cols.each do |id, desc|
                _th! desc, data_sort: 'string'
              end
              _th 'Last Event', data_sort: 'string'
              _th 'Twitter'
            end
            _tbody do
              conflist.each do | conf |
                _tr_ do
                  _td do 
                    _a conf['name'], href: conf['website']
                  end
                  if conf[SPEAKERKIT] then
                    cols.each do |id, desc|
                      _td! conf[SPEAKERKIT][id]
                    end            
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
          "https://github.com/afilina/dev-community-data" => "FOSS conference listing - ConFoo",
          "https://github.com/szabgab/codeandtalk.com" => "FOSS conference listing - CodeAndTalk",
          "https://www.apache.org/foundation/marks/resources" => "Trademark Site Map",
          "https://www.apache.org/foundation/marks/list/" => "Official Apache Trademark List"
        })
      end
    end
  end
end
    