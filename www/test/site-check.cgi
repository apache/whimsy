#!/usr/bin/env ruby
$LOAD_PATH.unshift File.realpath(File.expand_path('../../../lib', __FILE__))
require 'json'
require 'whimsy/asf'
require 'wunderbar'
require 'wunderbar/bootstrap'
require 'wunderbar/jquery/stupidtable'
require 'net/http'

PAGETITLE = 'Apache TLP Website Link Checks'
cols = %w( events foundation license sponsorship security thanks )
DATAURI = 'https://whimsy.apache.org/public/site-scan.json'

def analyze(sites)
    counts = Hash.new { |h, k| h[k] = Hash.new(&h.default_proc) }
    { 
      'events' => %r{apache.org/events/current-event}i,
      'license' => %r{apache.org/license}i,
      'sponsorship' => %r{apache.org/foundation/sponsorship}i,
      'security' => %r{apache.org/security}i,
      'thanks' => %r{apache.org/foundation/thanks}i
    }.each do |nam, pat|
      counts[nam]['text-success'] = sites.select{ |k, site| site[nam] =~ pat  }.count
      counts[nam]['text-warning'] = 0 # Reorder output 
      counts[nam]['text-danger'] = sites.select{ |k, site| site[nam].nil? }.count
      counts[nam]['text-warning'] = sites.size - counts[nam]['text-success'] - counts[nam]['text-danger']
    end
    
    [
      counts, {
      'text-success' => 'Sites with links to primary ASF page',
      'text-warning' => 'Sites with link, but not ASF one',
      'text-danger' => 'Sites with no link for this topic'
      }
    ]
end

_html do
  _head do
    _style %{
      .table td {font-size: smaller;}
    }
  end

  _body? do

    local_copy = File.expand_path('../public/site-scan.json').untaint

    if File.exist? local_copy
      crawl_time = File.mtime(local_copy).rfc2822
      sites = JSON.parse(File.read(local_copy))
    else
      response = Net::HTTP.get_response(URI(DATAURI))
      crawl_time = response['last-modified']
      sites = JSON.parse(response.body)
    end
    analysis = analyze(sites)
    
    _whimsy_header PAGETITLE

    _whimsy_content do
      _div.panel.panel_default do
        _div!.panel_heading 'Common Links Found On TLP Sites'
        _div.panel_body do
          _ 'Current (beta) status of Apache PMC top level websites vis-a-vis '
          _a 'required links', href: 'https://www.apache.org/foundation/marks/pmcs#navigation'
          _ '.  '
          _a 'See crawler code', href: 'https://whimsy.apache.org/tools/site-check.rb'
          _ ' and '
          _a 'raw JSON data', href: DATAURI         
          _ ".  Last crawl time: #{crawl_time} over #{sites.size} sites."
          _br
          _ul do
            analysis[1].each do |cls, desc|
              _li desc, class: cls
            end
          end  
        end
      end
      _table.table.table_condensed.table_striped do
        _thead do  
          _tr do
            _th! 'Project', data_sort: 'string-ins'
            cols.each do |col|
              _th! data_sort: 'string' do 
                _ col.capitalize
                analysis[0][col].each do |cls, val|
                  _ ' '
                  _span.badge val, class: cls
                end
              end
            end
          end
        end

        _tbody do
          sites.each do |n, links|
            _tr do
              _td do 
                _a! "#{links['display_name']}", href: links['uri']
              end
              cols.each do |c|
                if not links[c]
                  _td ''
                elsif links[c] =~ /^http/
                  _td do
                    _a links[c].sub(/https?:\/\//, '').
                      sub(/(www\.)?apache\.org/i, 'a.o'), href: links[c]
                  end
                else
                  _td links[c]
                end
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
      "https://www.apache.org/foundation/marks/pmcs" => "Apache Project Branding Policy",
      "https://www.apache.org/foundation/marks/resources" => "Trademark Site Map",
      "https://www.apache.org/foundation/marks/list/" => "Official Apache Trademark List"
    })
  end
end
