# Shared code used by pods.cgi and site.cgi

# ensure that there is a path (even a slash will do) after the script name
unless ENV['PATH_INFO'] and not ENV['PATH_INFO'].empty?
  print "Status: 301 Moved Permanently\r\n"
  print "Location: #{ENV['SCRIPT_URL']}/\r\n"
  print "\r\n"
  exit
end

$LOAD_PATH.unshift '/srv/whimsy/lib'
require 'json'
require 'net/http'
require 'time' # for httpdate
require 'whimsy/sitestandards'

# Gather and analyze scans for TLP websites
sites, crawl_time = SiteStandards.get_sites(cgi_for_tlps)
checks_performed = SiteStandards.get_checks(cgi_for_tlps)
analysis = SiteStandards.analyze(sites, checks_performed)

# Allow CLI testing, e.g. "PATH_INFO=/ ruby www/site.cgi >test.json"
# SCRIPT_NAME will always be set for a CGI invocation
unless ENV['SCRIPT_NAME']
  puts JSON.pretty_generate(analysis)
  exit
end

# Only required for CGI use
# if these are required earlier, the code creates an unnecessary 'assets' directory

require 'wunderbar'
require 'wunderbar/bootstrap'
require 'wunderbar/jquery/stupidtable'
require 'whimsy/asf/themes'
require 'whimsy/sitewebsite'

_html do
  _head do
    _style %{
      .table td {font-size: smaller;}
    }
  end
  if cgi_for_tlps
    other = "/pods/"
    other_text = "PPMC Podling Website Checker"
  else
    other = "/site/"
    other_text = "TLP Website Checker"
  end
  _body? do
    _whimsy_body(
      title: PAGETITLE,
      subtitle: "Checking #{cgi_for_tlps ? 'Project' : 'Podling'} Websites For required content",
      related: {
        "/committers/tools" => "Whimsy Tool Listing",
        other => other_text,
        "https://www.apache.org/foundation/marks/pmcs#navigation" => "Required PMC Links Policy",
        "https://github.com/apache/whimsy/blob/master/www#{ENV['SCRIPT_NAME']}" => "See This Source Code",
        "mailto:dev@whimsical.apache.org?subject=[SITE] Website Checker Question" => "Questions? Email Whimsy PMC"
      },
      helpblock: -> {
        unless cgi_for_tlps
          _div.bg_danger %{NOTE: most podlings may not pass these checks yet during incubation -
                           but they are expected to pass them before graduation.}
        end
        _p do
          _ 'This script periodically crawls all Apache project and podling websites to check them '
          _ 'for a few specific links or text blocks that all projects are expected to have.'
          _ 'The checks include verifying that all '
          _a 'required links', href: 'https://www.apache.org/foundation/marks/pmcs#navigation'
          _ ' appear on a project homepage, along with an "image" check if project logo files are in apache.org/img'
        end
        _p! do
          _a 'View the crawler code', href: 'https://github.com/apache/whimsy/blob/master/tools/site-scan.rb'
          _ ', '
          _a 'website display code', href: "https://github.com/apache/whimsy/blob/master/www#{ENV['SCRIPT_NAME']}"
          _ ', '
          _a 'validation checks details', href: "https://github.com/apache/whimsy/blob/master/lib/whimsy/sitewebsite.rb"
          _ ', and '
          _a 'raw JSON data', href: "#{SiteStandards.get_url(false)}#{SiteStandards.get_filename(cgi_for_tlps)}"
          _ '.'
          _br
          _ "Last crawl time: #{crawl_time} over #{sites.size} websites."
        end
      }
    ) do
      # Encapsulate data display (same for projects and podlings)
      display_application(path_info, sites, analysis, checks_performed, cgi_for_tlps)
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
