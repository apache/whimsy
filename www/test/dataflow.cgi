#!/usr/bin/env ruby
# Wvisible:tools Crawl data sources and emit /public related links
$LOAD_PATH.unshift File.realpath(File.expand_path('../../../lib', __FILE__))
require 'json'
require 'whimsy/asf'
require 'wunderbar'
require 'wunderbar/bootstrap'

PAGETITLE = 'Public Datafiles And Dependencies'

_html do
  _body? do
    _whimsy_header PAGETITLE
    deplist = JSON.parse(File.read('dataflow.json')) 
    _whimsy_content do
      _p %{ Whimsy tools consume and produce a variety of data files 
        about PMCs and the ASF as a whole.  This non-comprehensive 
        page explains which tools generate what intermediate data, 
        and where the canonical underlying data sources are (many
        of which are privately stored).
        }

      _ul do
        deplist.each do |dep, info|
          _li do
            _a '', name: dep
            if dep =~ /http/i then
              _code do
                _a File.basename(dep), href: dep
              end
            else
              _code dep
            end
            _ info['description']
            _br
            if info['maintainer'] =~ %r{/} then
              _span.text_muted "Maintained by: Whimsy PMC using script: #{info['maintainer']}"
            else
              _a.text_muted "Maintained by role/PMC: #{info['maintainer']}", href: "https://whimsy.apache.org/roster/orgchart/#{info['maintainer']}"
            end
            _br
            if info.key?('sources') then
              _ul do
                _span.text_muted 'Derived from:'
                info['sources'].each do |src|
                  _li do 
                    _a "#{src}", href: "##{src}"
                  end
                end
              end
            else
              _br # Add a little more space
            end
          end
        end
      end
    end
  end
end
