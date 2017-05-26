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
        _ ' listing of the useful data and tools that Whimsy provides to Apache committers.'
        _br
        _ 'It is generated automatically from tools that opt-in. Future improvements 
        include automatically noting which tools require which auth (public|committer|member|officer).'
        _br
        _ 'If you find this useful, please let us know at dev@whimsical!.'
      }
    ) do
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
