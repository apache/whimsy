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

    ASF::Podlings.to_enum.sort.each do |name, description|
      next if description[:status] == 'retired'
      next if description[:status] == 'graduated'

      _tr_ do
        _td! do
          _a name, href: "http://incubator.apache.org/projects/#{name}.html"
        end

        _td description[:status]
        _td description[:reporting].join(', ')
        _td lists.select {|list| list.start_with? "#{name}-"}.join(', ')
      end
    end
  end
end
