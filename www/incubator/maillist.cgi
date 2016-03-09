#!/usr/bin/env ruby
$LOAD_PATH.unshift File.realpath(File.expand_path('../../../lib', __FILE__))

require 'whimsy/asf'
require 'wunderbar/bootstrap'

_html do
  lists = ASF::Mail.lists

  _table.table do
    _tr do
      _th 'podling'
      _th 'status'
      _th 'reports'
      _th 'mailing lists'
    end

    ASF::Podling.list.sort_by {|podling| podling.name}.each do |podling|
      next if podling.status == 'retired'
      next if podling.status == 'graduated'

      _tr_ do
        _td! do
          _a podling.display_name, 
            href: "http://incubator.apache.org/projects/#{podling.name}.html"
        end

        _td podling.status
        _td podling.reporting.join(', ')
        _td lists.select {|list| list.start_with? "#{podling.name}-"}.join(', ')
      end
    end
  end
end
