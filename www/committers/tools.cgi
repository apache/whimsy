#!/usr/bin/env ruby
PAGETITLE = "Listing Of Whimsy Tools" # Wvisible:tools

$LOAD_PATH.unshift '/srv/whimsy/lib'
require 'json'
require 'whimsy/asf'
require 'wunderbar'
require 'wunderbar/bootstrap'
require '../../tools/wwwdocs.rb'

NONCGIS = {
  '/board/agenda/' =>
    [ 'Board Agenda Tool',
      ['board', 'meeting'],
    'text-primary'],
  '/roster/' =>
    [ 'ASF Roster Tool',
      ['orgchart'],
    'text-muted']
}

_html do
  _body? do
    _whimsy_body(
      title: PAGETITLE,
      related: {
        "https://projects.apache.org/" => "Apache Project Listing",
        "https://infra.apache.org/services.html" => "Infra Reference Pages",
        "https://github.com/apache/whimsy/blob/master/www/committers/tools.cgi" => "See This Code",
        "mailto:dev@whimsical.apache.org?subject=[FEEDBACK] committers/tools idea" => "Email Feedback To dev@whimsical"
      },
      helpblock: -> {
        _p.pull_right do
          _ 'This page shows a '
          _em 'partial'
          _ ' listing of tools that Whimsy provides.'
        end
        emit_authmap
      }
    ) do
      scan = get_annotated_scan(File.join("..", SCANDIR))
      scan.merge!(NONCGIS)
      scan_by = Hash.new{|h,k| h[k]=Array.new}
      # Create array entry for each category
      scan.each{ |k,v| v[1].each {|l| scan_by[l] << [k,v]}}
      _ul.list_inline do
        scan_by.sort.each do |cat, _l|
          _li do
            _a cat.capitalize, href: "##{cat}"
          end
        end
      end
      scan_by.sort.each do |category, links|
        _ul.list_group do
          _li.list_group_item.active do
            _span category.capitalize, id: category
          end
          links.sort_by{|_k, v| v}.each do |l, desc|
            _li.list_group_item do
              if 2 == desc.length
                _span.glyphicon :aria_hidden, class: AUTHPUBLIC
              else
                _span class: desc[2], aria_label: AUTHMAP.key(desc[2]), title: AUTHMAP.key(desc[2]) do
                  _span.glyphicon.glyphicon_lock :aria_hidden
                end
              end
              _a desc[0], href: l
              _ ' - '
              _code! do
                _a l, href: l
              end
            end
          end
        end
      end
    end
  end
end
