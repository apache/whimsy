#!/usr/bin/env ruby
PAGETITLE = 'Public Datafiles And Dependencies' # Wvisible:tools

$LOAD_PATH.unshift File.realpath(File.expand_path('../../../lib', __FILE__))
require 'json'
require 'whimsy/asf'
require 'wunderbar'
require 'wunderbar/bootstrap'

DATAFLOWDATA = 'dataflow.json'
GITWHIMSY = 'https://github.com/apache/whimsy/blob/master'

_html do
  _body? do
    _whimsy_header PAGETITLE
    deplist = JSON.parse(File.read(DATAFLOWDATA)) 
    _whimsy_content do
      _div.row do
        _div.col_sm_11 do
          _div.panel.panel_primary do
            _div.panel_heading {_h3.panel_title 'What Data Comes From Where'}
            _div.panel_body do
              _p %{ Whimsy tools consume and produce a variety of data files 
                about PMCs and the ASF as a whole.  This non-comprehensive 
                page explains which tools generate what intermediate data, 
                and where the canonical underlying data sources are (many
                of which are privately stored). .json files generated in 
                /public are consumed by many other websites.
              }
              _p do 
                _ %{ Whimsy has a number of cron jobs - typically hourly - 
                  that periodically regenerate the /public directory, but 
                  only when the underlying data source has changed.
                  See the 
                }
                _a 'server docs for more info.', href: 'https://github.com/apache/whimsy/blob/master/DEPLOYMENT.md'
              end
            end
          end
        end
      end
      
      _div.row do
        _div.col_sm_11 do
          _ul.list_group do
            deplist.each do |dep, info|
              _li.list_group_item do
                _a '', name: dep.gsub(/[#%\[\]\{\}\\"<>]/, '')
                if dep =~ /http/i then
                  _code! do
                    _a! File.basename(dep), href: dep
                  end
                elsif dep =~ %r{\A/} then
                  _code! do
                    _a! dep, href: "#{GITWHIMSY}#{dep}"
                  end              
                else
                  _code! dep
                end
                _ " #{info['description']}"
                _br
                if info['maintainer'] =~ %r{/} then
                  _span.text_muted 'Maintained by: Whimsy PMC using script: '
                  _a.text_muted "#{info['maintainer']}", href: "#{GITWHIMSY}#{info['maintainer']}"
                else
                  _span.text_muted 'Maintained by role/PMC: '
                  _a.text_muted "#{info['maintainer']}", href: "https://whimsy.apache.org/roster/orgchart/#{info['maintainer']}"
                end
                _br
                if info.key?('sources') then
                  _span 'Derived from:'
                  _ul do
                    info['sources'].each do |src|
                      _li do 
                        _a "#{src}", href: "##{src.gsub(/[#%\[\]\{\}\\"<>]/, '')}"
                      end
                    end
                  end
                end
              end
            end
          end
        end
      end
      
      _p do 
        _ "The #{DATAFLOWDATA} file is currently a manually maintained file where the hash key identifies a file: "
        _ul do
          _li "Starting with 'http' means it's at a public URL"
          _li "Starting with '/' means it's a path within whimsy repo"
          _li "All other paths means it's an SVN/Git reference from repository.yml"
        end
        _ul do
          _li "Maintainers starting with '/' are a path to a script"
          _li "All other maintainers are a role or PMC"
        end
      end
    end
  end
end
