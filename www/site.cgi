#!/usr/bin/env ruby

# ensure that there is a path (even a slash will do) after the script name
unless ENV['PATH_INFO'] and not ENV['PATH_INFO'].empty?
  print "Status: 301 Moved Permanently\r\n"
  print "Location: #{ENV['SCRIPT_URL']}/\r\n"
  print "\r\n"
  exit
end

$LOAD_PATH.unshift File.realpath(File.expand_path('../../lib', __FILE__))
require 'json'
require 'whimsy/asf'
require 'wunderbar'
require 'wunderbar/bootstrap'
require 'wunderbar/jquery/stupidtable'
require 'net/http'

PAGETITLE = 'Apache TLP Website Link Checks'
cols = %w( events foundation license sponsorship security thanks copyright trademarks )
CHECKS = { 
  'copyright'   => %r{[Cc]opyright [^.]+ Apache Software Foundation}, # Do we need '[Tt]he ASF'?
  'foundation'   => %r{.},
  # TODO more checks needed here, e.g. ASF registered and 3rd party marks
  'trademarks'  => %r{trademarks of [Tt]he Apache Software Foundation},
  'events'      => %r{apache.org/events/current-event},
  'license'     => %r{apache.org/licenses/$}, # should link to parent license page only
  'sponsorship' => %r{apache.org/foundation/sponsorship},
  'security'    => %r{apache.org/[Ss]ecurity},
  'thanks'      => %r{apache.org/foundation/thanks},
}
DATAURI = 'https://whimsy.apache.org/public/site-scan.json'

def analyze(sites)
    success = Hash.new { |h, k| h[k] = Hash.new(&h.default_proc) }
    counts = Hash.new { |h, k| h[k] = Hash.new(&h.default_proc) }
    CHECKS.each do |nam, pat|
      success[nam] = sites.select{ |k, site| site[nam] =~ pat  }.keys
      counts[nam]['label-success'] = success[nam].count
      counts[nam]['label-warning'] = 0 # Reorder output 
      counts[nam]['label-danger'] = sites.select{ |k, site| site[nam].nil? }.count
      counts[nam]['label-warning'] = sites.size - counts[nam]['label-success'] - counts[nam]['label-danger']
    end
    
    [
      counts, {
      'label-success' => '# Sites with links to primary ASF page',
      'label-warning' => '# Sites with link, but not an expected ASF one',
      'label-danger' => '# Sites with no link for this topic'
      }, success
    ]
end

def label(analysis, links, c, n)
  if not links[c]
    'label-danger'
  elsif analysis[2].include? c and not analysis[2][c].include? n
    'label-warning'
  else
    'label-success'
  end
end

_html do
  _head do
    _style %{
      .table td {font-size: smaller;}
    }
  end

  _body? do

    path = env['PATH_INFO']

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
              _li.label desc, class: cls
            end
          end  
        end
      end

      if path_info =~ %r{/project/(.+)}
        # details for an individual project
        project = $1
        links = sites[project]
        _h2 do
          _a links['display_name'], href: links['uri']
        end
        _table.table.table_striped do
          _tbody do
            cols.each do |col|
              _tr do
                _td col.capitalize
                _td links[col], class: label(analysis, links, col, project)
              end
            end
          end
        end
      elsif path_info =~ %r{/check/(.+)}
        # details for a single check
        col = $1
        _h2 col.capitalize
        if CHECKS.include? col
          _p! do
            _ '(Expected to match the regular expression: '
            _code CHECKS[col].inspect
            _ ')'
          end
        end
        _table.table do
          _tbody do
	    sites.each do |n, links|
              _tr class: label(analysis, links, col, n) do
                _td do 
                  _a links['display_name'], href: links['uri']
                end
                _td links[col]
              end
            end
          end
        end
      else
        # overview
	_table.table.table_condensed.table_striped do
	  _thead do  
	    _tr do
	      _th! 'Project', data_sort: 'string-ins'
	      cols.each do |col|
		_th! data_sort: 'string' do 
		  _a col.capitalize, href: "check/#{col}"
		  _br
		  analysis[0][col].each do |cls, val|
		    _ ' '
		    _span.label val, class: cls
		  end
		end
	      end
	    end
	  end

          sort_order = {
            'label-success' => 1,
            'label-warning' => 2,
            'label-danger'  => 3
          }

	  _tbody do
	    sites.each do |n, links|
	      _tr do
		_td do 
		  _a "#{links['display_name']}", href: "project/#{n}"
		end
		cols.each do |c|
		  cls = label(analysis, links, c, n)
		  _td '', class: cls, data_sort_value: sort_order[cls]
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
