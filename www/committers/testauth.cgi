#!/usr/bin/env ruby
PAGETITLE = "Board Agenda Auth Tester" # Wvisible:board tools
#
# Small CGI to help debug board agenda authentication issues
#

$LOAD_PATH.unshift '/srv/whimsy/lib'
require 'wunderbar'
require 'wunderbar/bootstrap'
require 'whimsy/asf/rack'
require 'whimsy/asf/agenda'

_html do
  _whimsy_body(
    title: PAGETITLE,
    related: {
      '/board/minutes/' => 'Board Meeting Minutes (public)',
      '/board/agenda/' => 'Board Agenda Tool (restricted)',
      '/status/' => 'Whimsy Server Status'
    },
    helpblock: -> {
      _ 'This script checks your authorization to use the agenda tool, and checks if you are listed as attending the current board meeting in the upcoming official agenda.'
    }
  ) do
    FOUNDATION_BOARD = ASF::SVN['foundation_board']
    agendafile = Dir[File.join(FOUNDATION_BOARD, 'board_agenda_*.txt')].max
    agenda = ASF::Board::Agenda.parse(File.read(agendafile))
    roll = agenda.find {|item| item['title'] == 'Roll Call'}

    person = ASF::Auth.decode(env)
    _p %{ Your data for meeting: #{File.basename(agendafile)} }
    _table do
      _tr do
        _td 'Your id'
        _td person.id
      end

      _tr do
        _td 'ASF Member?'
        _td person.asf_member?
      end

      _tr do
        _td 'PMC chair?'
        _td ASF.pmc_chairs.include? person
      end

      _tr do
        _td 'Attending'
        _td roll['people'].keys.include? person.id
      end
    end
  end
end
