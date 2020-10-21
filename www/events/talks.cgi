#!/usr/bin/env ruby
PAGETITLE = "Apache Related Talks Listing" # Wvisible:events

$LOAD_PATH.unshift '/srv/whimsy/lib'
require 'json'
require 'whimsy/asf'
require 'wunderbar'
require 'wunderbar/bootstrap'
require 'wunderbar/jquery'
require "../../tools/comdevtalks.rb"

talks = {}
submitters = {}
TOPICMAP = {
  'apacheway' => "The Apache Way of Project Governance And Behaviors",
  'community' => "Community Health And Maintenance",
  'developers' => "Focus On Developers In Apache Projects",
  'incubator' => "About The Apache Incubator And Joining The ASF",
  'contributors' => "Focus On Non-Technical Project Contributors"
}

def _talk(talk, submitters, parent, n)
  _div.panel.panel_info  id: talk[0] do
    talk = talk[1] # originally an array of ['Apache_Way_2017', {...} ]
    _div.panel_heading role: "tab", id: "#{parent}#{n}" do
      _h3.panel_title do
        _a.collapsed role: "button", data_toggle: "collapse",  aria_expanded: "false", data_parent: "##{parent}", href: "##{parent}-c#{n}", aria_controls: "#{parent}-c#{n}" do
          _ talk['title']
          _ ' '
          _span.caret
        end
        _br
        _span.small talk['teaser']
      end
    end
    _div.panel_collapse.collapse id: "#{parent}-c#{n}", role: "tabpanel", aria_labelledby: "#{parent}#{n}" do
      # TODO fix to display both submitter and/or speaker(s)
      submitter = submitters[talk['submitter']]
      submitter = talk['submitter'] unless submitter
      _table.table.table_condensed do
        _thead do
          _tr do
            _th do
              _ submitter['name']
            end
          end
        end
        _tbody do
          _tr do
            _td do
              # TODO allow markdown styles
              talk['abstract'].split(/\n+/).each do |line|
                _p line
              end
            end
          end
          if talk['slides']
            _tr do
              _td do
                _a! href: talk['slides'] do
                  _span!.glyphicon class: 'glyphicon-file'
                  _! ' Session Slides'
                end
              end
            end
          end
          if talk['video']
            _tr do
              _td do
                _a! href: talk['video'] do
                  _span!.glyphicon class: 'glyphicon-facetime-video'
                  _! ' Watch The Video'
                end
              end
            end
          end
          if submitter['bio']
            _tr do
              _td do
                _h4 do
                  _span.glyphicon class: 'glyphicon-user'
                  _ ' Speaker Bio'
                end
                _ submitter['bio']
              end
            end
          end
        end
      end
    end
  end
end

_html do
  _body? do
    _whimsy_body(
      title: PAGETITLE,
      subtitle: 'Great Conference Talks About Apache Community',
      related: {
        "https://community.apache.org/" => "Apache Community Development",
        "https://community.apache.org/speakers/" => "Apache Speaker Resources",
        "https://community.apache.org/speakers/slides.html" => "More Apache-related Slides",
        "https://apachecon.com/" => "ApacheCon Conferences"
      },
      helpblock: -> {
        _p do
          _ 'Curated listing of selected Apache '
          _em 'non-technical'
          _ %{
            talks - about the Apache Way, licenses, brands, governance, and ASF history.
            This is just a small sample of the many great talks on open source communities from our many experienced Apache speakers.
            }
        end
        _p do
          _ 'To be included here, talks must have gotten good feedback at an ApacheCon, and must include slides and preferably video/audio. '
          _a 'See the source data.', href: COMDEVTALKS
          _ 'Many more Apache-related slides are on the '
          _a 'ComDev Slides page.', href: 'https://community.apache.org/speakers/slides.html'
        end
      }
    ) do
      talks, submitters = get_talks_submitters()
      alltalks = talks.group_by { |t| t[1]['topics'][0]}
      _p do
        _ 'All talks by topics: '
        alltalks.each_key do | topic |
          _a topic, href: "##{topic}"
          _ ' | ' unless topic == alltalks.keys.last
        end
      end
      alltalks.each do | topic, all_by_cat |
        _h2 do
          _ "#{TOPICMAP[topic]} "
          _span.small "(#{topic})"
        end
        _div.panel_group id: topic, role: "tablist", aria_multiselectable: "true" do
          all_by_cat.each_with_index do |talk, num|
            _talk(talk, submitters, topic, num)
          end
        end
      end
    end
  end
end
