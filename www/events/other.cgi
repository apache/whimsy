#!/usr/bin/env ruby
PAGETITLE = "Other FOSS Conference Listings" # Wvisible:events

$LOAD_PATH.unshift '/srv/whimsy/lib'
require 'json'
require 'net/http'
require 'whimsy/asf'
require 'whimsy/cache'
require 'wunderbar'
require 'wunderbar/bootstrap'
require 'wunderbar/jquery/stupidtable'
require 'date'


$cache = Cache.new(dir: 'other')

def getJSON(url, _name)
  _uri, response, _status = $cache.get(url)
#  $stderr.puts "#{name} #{uri} #{status}"
  JSON.parse(response)
end

DIRURL = 'https://api.github.com/repos/afilina/dev-community-data/contents/data/conferences'

conflist = []

getJSON(DIRURL,'index').each do |e|
  conflist << getJSON(e['download_url'], e['name'])
end

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
    _whimsy_body(
      title: PAGETITLE,
      related: {
        "https://github.com/afilina/dev-community-data" => "FOSS conference listing - ConFoo",
        "https://github.com/szabgab/codeandtalk.com" => "FOSS conference listing - CodeAndTalk",
        "https://www.apache.org/foundation/marks/resources" => "Trademark Site Map",
        "https://www.apache.org/foundation/marks/list/" => "Official Apache Trademark List"
      },
      helpblock: -> {
        _ "Listing #{conflist.count} self-reported FOSS Conferences and their claimed speaker support status.  Data from "
        _a_ 'afilina/dev-community-data', href: 'https://github.com/afilina/dev-community-data/'
        _ ', calendar website at '
        _a_ 'ConFoo Community', href: 'https://community.confoo.ca/'
        _ '.  Click column header to sort table.'
        _br
        _p 'Conferences that include speaker benefit types:'
        _ul do
          counts.each do |s, num|
            _li "#{cols[s]}: #{num}"
          end
        end
      }
    ) do
    _table.table.table_hover.table_striped do
      _thead_ do
        _tr do
          _th 'Conference', data_sort: 'string'
          cols.each do |_id, desc|
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
                cols.each do |id, _desc|
                  _td! conf[SPEAKERKIT][id]
                end
              else
                _td 'Unknown'
                _td 'Unknown'
                _td 'Unknown'
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
    end
  end
end
