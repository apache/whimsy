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
require 'net/http'
require 'time' # for httpdate

PAGETITLE = "Apache TLP Website Checks" # Wvisible:sites,brand
SITE_PASS = 'label-success'
SITE_WARN = 'label-warning'
SITE_FAIL = 'label-danger'
cols = %w( uri events foundation image license sponsorship security thanks copyright trademarks )
CHECKS = { 
  'uri'         => %r{https?://[^.]+\.apache\.org},
  'copyright'   => %r{[Cc]opyright [^.]+ Apache Software Foundation}, # Do we need '[Tt]he ASF'?
  'foundation'  => %r{.},
  'image'  => %r{.},
  # TODO more checks needed here, e.g. ASF registered and 3rd party marks
  'trademarks'  => %r{trademarks of [Tt]he Apache Software Foundation},
  'events'      => %r{^https?://.*apache.org/events/current-event},
  'license'     => %r{^https?://.*apache.org/licenses/$}, # should link to parent license page only
  'sponsorship' => %r{^https?://.*apache.org/foundation/sponsorship},
  'security'    => %r{^https?://.*apache.org/[Ss]ecurity},
  'thanks'      => %r{^https?://.*apache.org/foundation/thanks},
}
DOCS = {
  'uri'         => ['https://www.apache.org/foundation/marks/pmcs#websites',
                    'The homepage for any ProjectName must be served from http://ProjectName.apache.org'],
  'copyright'   => ['https://www.apache.org/legal/src-headers.html#headers',
                    'All website content SHOULD include a copyright notice for the ASF.'],
  'foundation'  => ['https://www.apache.org/foundation/marks/pmcs#navigation',
                    'All projects must feature some prominent link back to the main ASF homepage at http://www.apache.org/'],
  'image'  => ['https://www.apache.org/img/',
                    'Projects SHOULD include a 212px wide copy of their logo in https://www.apache.org/img/ to be included in ASF homepage.'],
  'trademarks'  => ['https://www.apache.org/foundation/marks/pmcs#attributions',
                    'All project or product homepages must feature a prominent trademark attribution of all applicable Apache trademarks'],
  'events'      => ['https://www.apache.org/events/README.txt',
                    'Projects SHOULD include a link to any current ApacheCon event, as provided by VP, Conferences.'],
  'license'     => ['https://www.apache.org/foundation/marks/pmcs#navigation',
                    '"License" should link to: http://www.apache.org/licenses/'],
  'sponsorship' => ['https://www.apache.org/foundation/marks/pmcs#navigation',
                    '"Sponsorship" or "Donate" should link to: http://www.apache.org/foundation/sponsorship.html'],
  'security'    => ['https://www.apache.org/foundation/marks/pmcs#navigation',
                    '"Security" should link to either to a project-specific page [...], or to the main http://www.apache.org/security/ page'],
  'thanks'      => ['https://www.apache.org/foundation/marks/pmcs#navigation',
                    '"Thanks" should link to: http://www.apache.org/foundation/thanks.html'],
}
DATAURI = 'https://whimsy.apache.org/public/site-scan.json'

def analyze(sites)
    success = Hash.new { |h, k| h[k] = Hash.new(&h.default_proc) }
    counts = Hash.new { |h, k| h[k] = Hash.new(&h.default_proc) }
    CHECKS.each do |nam, pat|
      success[nam] = sites.select{ |k, site| site[nam] =~ pat  }.keys
      counts[nam][SITE_PASS] = success[nam].count
      counts[nam][SITE_WARN] = 0 # Reorder output 
      counts[nam][SITE_FAIL] = sites.select{ |k, site| site[nam].nil? }.count
      counts[nam][SITE_WARN] = sites.size - counts[nam][SITE_PASS] - counts[nam][SITE_FAIL]
    end
    
    [
      counts, {
      SITE_PASS => '# Sites with links to primary ASF page',
      SITE_WARN => '# Sites with link, but not an expected ASF one',
      SITE_FAIL => '# Sites with no link for this topic'
      }, success
    ]
end

def getsites
    local_copy = File.expand_path('../public/site-scan.json', __FILE__).untaint
    if File.exist? local_copy
      crawl_time = File.mtime(local_copy).httpdate # show time in same format as last-mod
      sites = JSON.parse(File.read(local_copy))
    else
      response = Net::HTTP.get_response(URI(DATAURI))
      crawl_time = response['last-modified']
      sites = JSON.parse(response.body)
    end
  return sites, crawl_time
end

sites, crawl_time = getsites()

analysis = analyze(sites)

# Allow CLI testing, e.g. "PATH_INFO=/ ruby www/site.cgi >test.json"
# SCRIPT_NAME will always be set for a CGI invocation
unless ENV['SCRIPT_NAME']
  puts JSON.pretty_generate(analysis)
  exit
end

# Only required for CGI use
# if these are required earlier, the code creates an unnecessary 'assets' directory

require 'whimsy/asf/themes'
require 'wunderbar'
require 'wunderbar/bootstrap'
require 'wunderbar/jquery/stupidtable'

# Determine the color of a given table cell, given:
#   - overall analysis of the sites, in particular the third column
#     which is a list projects that successfully matched the check
#   - list of links for the project in question
#   - the column in question (which indicates the check being reported on)
#   - the name of the project
def label(analysis, links, col, name)
  if not links[col]
    SITE_FAIL
  elsif analysis[2].include? col and not analysis[2][col].include? name
    SITE_WARN
  else
    SITE_PASS
  end
end

def displayProject(project, links, cols, analysis)
  _whimsy_panel_table(
    title: "Site Check For Project - #{links['display_name']}",
    helpblock: -> {
      _a href: '../', aria_label: 'Home to site checker' do
        _span.glyphicon.glyphicon_home :aria_hidden
      end
      _span.glyphicon.glyphicon_menu_right
      _ ' Results for project: '
      _a links['display_name'], href: links['uri']
      _ ' Check Results column is the actual text found on the project homepage for this check (when applicable).'
    }
  ) do
    _table.table.table_striped do
      _tbody do
        _thead do
          _tr do
            _th! 'Check Type'
            _th! 'Check Results'
            _th! 'Check Description'
          end
        end
        cols.each do |col|
          cls = label(analysis, links, col, project)
          _tr do
            _td do
              _a col.capitalize, href: "../check/#{col}"
            end
            
            if links[col] =~ /^https?:/
              _td class: cls do
                _a links[col], href: links[col]
              end
            else
              _td links[col], class: cls
            end
            
            _td do
              if cls != SITE_PASS
                if CHECKS.include? col
                  _ 'Expected to match regular expression: '
                  _code CHECKS[col].source
                  if DOCS.include? col
                    _ ' '
                    _a DOCS[col][1], href: DOCS[col][0]
                  end
                else
                  _ ''
                end
              end
            end
          end
        end
      end
    end
  end
end

def displayError(path)
  _whimsy_panel_table(
    title: "ERROR",
    helpblock: -> {
      _a href: '../', aria_label: 'Home to site checker' do
        _span.glyphicon.glyphicon_home :aria_hidden
      end
      _span.glyphicon.glyphicon_menu_right
      _span.text_danger "ERROR: The path #{path} is not a recognized command for this tool, sorry! "
    }
  ) do
    _p.bold 'ERROR - please try again.'
  end
end

_html do
  _head do
    _style %{
      .table td {font-size: smaller;}
    }
  end
  _body? do
    _whimsy_body(
    title: PAGETITLE,
    subtitle: 'Checking TLP Websites For required content',
    related: {
      "/committers/tools" => "Whimsy Tool Listing",
      "https://www.apache.org/foundation/marks/pmcs#navigation" => "Required PMC Links Policy",
      "https://github.com/apache/whimsy/blob/master/www#{ENV['SCRIPT_NAME']}" => "See This Source Code",
      "mailto:dev@whimsical.apache.org?subject=[SITE] Website Checker Question" => "Questions? Email Whimsy PMC"
    },
    helpblock: -> {
      _p do
        _ 'This script periodically crawls all Apache project websites to check them for a few specific links or text blocks that all projects are expected to have.'
        _ 'The checks include verifying that all '
        _a 'required links', href: 'https://www.apache.org/foundation/marks/pmcs#navigation'
        _ ' appear on a project homepage, along with an "image" check if project logo files are in apache.org/img'
      end
      _p! do
        _a 'View the crawler code', href: 'https://github.com/apache/whimsy/blob/master/tools/site-scan.rb'
        _ ', '
        _a 'website display code', href: 'https://github.com/apache/whimsy/blob/master/www/site.cgi'
        _ ', and '
        _a 'raw JSON data', href: DATAURI
        _ '.'
        _br
        _ "Last crawl time: #{crawl_time} over #{sites.size} websites."
      end
    }
    ) do
      
      if path_info =~ %r{/project/(.+)}
        # details for an individual project
        project = $1
        if sites[project]
          displayProject(project, sites[project], cols, analysis)
        else
          displayError(path_info)
        end
      elsif path_info =~ %r{/check/(.+)}
        # details for a single check
        col = $1
        _whimsy_panel_table(
          title: "Site Check Of Type - #{col.capitalize}",
          helpblock: -> {
            _a href: '../', aria_label: 'Home to site checker' do
              _span.glyphicon.glyphicon_home :aria_hidden
            end
            _span.glyphicon.glyphicon_menu_right
            if CHECKS.include? col
              _ ' Check Results are expected to match the regular expression: '
              _code CHECKS[col].source
              if DOCS.include? col
                _ ' '
                _a DOCS[col][1], href: DOCS[col][0]
              end
              _li.small " Click column badges to sort"
            else
              _span.text_danger "WARNING: the site checker may not understand type: #{col}, results may not be complete/available."
            end
          }
        ) do
          _table.table.table_condensed.table_striped do
            _thead do
              _tr do
                _th! 'Project', data_sort: 'string-ins'
                _th! data_sort: 'string' do 
                  _ 'Check Results'
                  _br
                  analysis[0][col].each do |cls, val|
                    _ ' '
                    _span.label val, class: cls
                  end
                end
              end
            end
            _tbody do
              sites.each do |n, links|
                _tr do
                  _td do 
                    _a links['display_name'], href: "../project/#{n}"
                  end
                  
                  if links[col] =~ /^https?:/
                    _td class: label(analysis, links, col, n) do
                      _a links[col], href: links[col]
                    end
                  else
                    _td links[col], class: label(analysis, links, col, n) 
                  end
                end
              end
            end
          end
        end
      else
        # overview
        _whimsy_panel_table(
          title: "Site Check - All Projects Results",
          helpblock: -> {
            _ul.list_inline do
              _li.small "Data key: "
              analysis[1].each do |cls, desc|
                _li.label desc, class: cls
              end
              _li.small " Click column badges to sort"
            end
          }
        ) do
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
              SITE_PASS => 1,
              SITE_WARN => 2,
              SITE_FAIL => 3
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
        end # of _whimsy_panel_table
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
