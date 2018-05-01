#!/usr/bin/env ruby

$LOAD_PATH.unshift File.realpath(File.expand_path('../../../lib', __FILE__))
require 'whimsy/asf/agenda'

records = 'http://www.apache.org/foundation/records/minutes/'

Dir.chdir ASF::SVN['foundation_board']

agendas = Dir['**/board_agenda_*'].sort_by {|name| File.basename(name)}[-12..-1]

_html do
  _h1 'Missing reports by month'

  _table do
    agendas.reverse.each do |agenda|
      parsed = ASF::Board::Agenda.parse(File.read(agenda.untaint), true)

      _tr_ do
        _td parsed.count {|report| report["missing"]}, align: 'right'
        _td do
          if agenda.include? 'archived'
            year = agenda[/\d+/]
            minutes = File.basename(agenda).sub('agenda', 'minutes')
            _a File.basename(agenda), href: "#{records}/#{year}/#{minutes}"
          else
            date = agenda[/\d+_\d+_\d+/].gsub('_', '-')
            _a File.basename(agenda), href: "agenda/#{date}/"
          end
        end
      end
    end
  end
end
