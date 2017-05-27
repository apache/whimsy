#!/usr/bin/env ruby
PAGETITLE = "Listing Of Whimsy Tools" # Wvisible:tools

$LOAD_PATH.unshift File.realpath(File.expand_path('../../../lib', __FILE__))
require 'json'
require 'whimsy/asf'
require 'wunderbar'
require 'wunderbar/bootstrap'
require '../../tools/wwwdocs.rb'

_html do
  _body? do
    _whimsy_body2(
      PAGETITLE, {
        "https://projects.apache.org/" => "Apache Project Listing",
        "https://reference.apache.org/" => "Infra Reference Pages",
        "https://github.com/apache/whimsy/blob/master/www/committers/tools.cgi" => "See This Code"
      },
      -> {
        _ 'This page shows a '
        _em 'partial'
        _ ' listing of tools that Whimsy provides. If you find this useful, please email dev@whimsical!'
        _ul do
          _li do
            _span.glyphicon :aria_hidden, class: "#{AUTHPUBLIC}"
            _ 'Publicly available'
          end
          AUTHMAP.each do |realm, style|
            _li do
              _span.glyphicon.glyphicon_lock :aria_hidden, class: "#{style}"
              _ "#{realm}"
            end
          end
        end
      }
    ) do
      scan = get_annotated_scan("../#{SCANDIR}")
      scan.group_by{ |k, v| v[1][0] }
        .each do | category, links |
        _ul.list_group do
          _li.list_group_item.active do
            _ category.capitalize
          end
          links.each do |l, desc|
            _li.list_group_item do
              if 2 == desc.length
                _span.glyphicon :aria_hidden, class: "#{AUTHPUBLIC}"
              else
                _span class: desc[2] do
                  _span.glyphicon.glyphicon_lock :aria_hidden
                end
              end
              _a "#{desc[0]}", href: l
              _ ' - '
              _code! do
                _a "#{l}", href: l
              end
            end
          end
        end
      end
    end
  end
end
