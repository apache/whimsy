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


# Simple cache for site pages
class Cache
  # Don't bother checking cache entries that are younger (seconds)
  # This is mainly intended for local testing
  attr_accessor :minage
  attr_accessor :enabled

  def initialize(dir: '/tmp/other-cache', minage: 3000, enabled: true)
    @dir = dir
    @enabled = enabled
    @minage = minage # default to 50 mins
    begin
      FileUtils.mkdir_p dir
    rescue
      @enabled = false
    end
  end

  def get(id, url)
    if not @enabled
      uri, res = fetch(url)
      return uri, res.body, 'nocache'
    end
    age, etag, uri, data = read_cache(id)
    if age < minage
      return uri, data, 'recent' # we have a recent cache entry
    end
    if data and etag
      # let's see if the page has been updated
      uri, res = fetch(url, {'If-None-Match' => etag})
      if res.is_a?(Net::HTTPSuccess)
        write_cache(id, uri, res)
        return uri, res.body, 'updated'
      elsif res.is_a?(Net::HTTPNotModified)
        path = makepath(id)
        mtime = Time.now
        File.utime(mtime, mtime, path) # show we checked the page
        return uri, data, 'unchanged'
      else
        return nil, res, 'error'
      end
    else
      uri, res = fetch(url)
      write_cache(id, uri, res)
      return uri, res.body, data ? 'no last mod' : 'missing'
    end
  end

  private

  # fetch uri, following redirects
  def fetch(uri, options={}, depth=1)
    if depth > 5
      raise IOError.new("Too many redirects (#{depth}) detected at #{url}")
    end
    uri = URI.parse(uri)
    Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https') do |http|
      request = Net::HTTP::Get.new(uri.request_uri)
      options.each do |k,v|
        request[k] = v
      end
      response = http.request(request)
      if response.code == '304' # Not modified
        return uri, response      
      elsif response.code =~ /^3\d\d/ # assume redirect
        fetch response['location'], options, depth+1
      else
        return uri, response
      end
    end
  end

  # File cache contains last modified followed by the data
  # The file mod time can be used to skip any checks for recently updated files
  def write_cache(id, uri, res)
    path = makepath(id)
    open path, 'wb' do |io|
      io.puts res['Etag']
      io.puts uri
      io.write res.body
    end
  end

  # return age, etag, uri, data
  def read_cache(id)
    path = makepath(id)
    mtime = File.stat(path).mtime rescue nil
    etag = nil
    data = nil
    uri = nil
    if mtime
      open path, 'rb' do |io|
        etag = io.gets.chomp
        uri = URI.parse(io.gets.chomp)
        data = io.read
      end
    end
    return Time.now - (mtime ? mtime : Time.new(0)), etag, uri, data
  end

  def makepath(id)
    name = id.gsub /[^\w]/, '_'
    File.join @dir, "#{name}"
  end

end

$cache = Cache.new()

def getJSON(url,name)
  uri, response, status = $cache.get(name, url)
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
    _whimsy_header PAGETITLE
    _whimsy_content do
      _div.row do
        _div.col_sm_10 do
          _whimsy_panel PAGETITLE do
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
        _whimsy_footer(
          related: {
            "https://github.com/afilina/dev-community-data" => "FOSS conference listing - ConFoo",
            "https://github.com/szabgab/codeandtalk.com" => "FOSS conference listing - CodeAndTalk",
            "https://www.apache.org/foundation/marks/resources" => "Trademark Site Map",
            "https://www.apache.org/foundation/marks/list/" => "Official Apache Trademark List"
          })
      end
    end
  end
end
    