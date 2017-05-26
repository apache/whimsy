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
    _whimsy_body2 title: PAGETITLE, related: {
      "https://projects.apache.org/" => "Learn About Apache Projects",
      "https://community.apache.org/" => "Get Community Help",
      "https://github.com/apache/whimsy/" => "Read The Whimsy Code"
    } do
      scan = scandir("../#{SCANDIR}") # TODO Should be a static generated file
      scan.reject{ |k, v| v[1] =~ /\A#{ISERR}/ }
        .group_by{ |k, v| v[1][0] }
        .each do | category, links |
        _ul.list_group do
          _li.list_group_item.active do
            _ category.capitalize
          end
          links.each do |l, desc|
            _li.list_group_item do
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
