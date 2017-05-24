#!/usr/bin/env ruby
PAGETITLE = 'Apache Related Talks Listing' # Wvisible:events

$LOAD_PATH.unshift File.realpath(File.expand_path('../../../lib', __FILE__))
require 'json'
require 'whimsy/asf'
require 'wunderbar'
require 'wunderbar/bootstrap'
require 'wunderbar/jquery'
require "../../tools/comdevtalks.rb"

talks = {}
submitters = {}

def _talk(talk, submitters, parent, n)
  _div.panel.panel_default  id: talk[0] do
    talk = talk[1] # originally an array of [Apache_Way_2017, {} ]
    _div.panel_heading role: "tab", id: "urh#{n}" do
      _h4.panel_title do
        _a.collapsed role: "button", data_toggle: "collapse",  aria_expanded: "false", data_parent: "##{parent}", href: "#urc#{n}", aria_controls: "urc#{n}" do
          _ talk['title']
        end
        _br
        _span.small talk['teaser']
      end
    end
    _div.panel_collapse.collapse id: "urc#{n}", role: "tabpanel", aria_labelledby: "urh#{n}" do
      # TODO fix to display both submitter and/or speaker(s)
      submitter = submitters[talk['submitter']]
      submitter = talk['submitter'] unless submitter
      _table.table.table_condensed do
        _thead do
          _tr do
            _th do
              _ "#{submitter['name']}" #TODO lookup name, bio
            end
          end
        end
        _tbody do
          _tr do
            _td do
              _ talk['abstract'] # TODO allow markdown styles
            end
          end
          if talk['slides']
            _tr do
              _td do
                _a! href: "#{talk['slides']}" do
                  _span!.glyphicon class: 'glyphicon_file'
                  _! ' Session Slides'
                end
              end
            end
          end
          if talk['video']
            _tr do
              _td do
                _a! href: "#{talk['video']}" do
                  _span!.glyphicon class: 'glyphicon_facetime_video'
                  _! ' Watch The Video'
                end
              end
            end
          end
          _tr do
            _td do
              _h4 "Speaker Bio"
              _ "#{submitter['bio']}"
            end
          end
        end
      end
    end
  end
end

_html do
  _body? do
    _whimsy_header PAGETITLE
    talks, submitters = get_talks_submitters()
    _whimsy_content do
      _p do
        _ 'DRAFT listing of curated Apache non-technical talks - about the Apache Way, licenses, brands, governance, and ASF history.'
        _a 'See the source data.', href: COMDEVTALKS
      end 
      
      parent = "talkz" # TODO: split up by category
      _div.panel_group id: parent, role: "tablist", aria_multiselectable: "true" do
        talks.each_with_index do |talk, num|
          _talk(talk, submitters, parent, num)
        end
      end
    end
    
    _whimsy_footer({
      "https://community.apache.org/" => "Apache Community Development",
      "https://community.apache.org/speakers/" => "Apache Speaker Resources",
      "https://apachecon.com/" => "ApacheCon Conferences"
      })
    end
  end
