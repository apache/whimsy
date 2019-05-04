#!/usr/bin/env ruby
##   Licensed to the Apache Software Foundation (ASF) under one or more
##   contributor license agreements.  See the NOTICE file distributed with
##   this work for additional information regarding copyright ownership.
##   The ASF licenses this file to You under the Apache License, Version 2.0
##   (the "License"); you may not use this file except in compliance with
##   the License.  You may obtain a copy of the License at
## 
##       http://www.apache.org/licenses/LICENSE-2.0
## 
##   Unless required by applicable law or agreed to in writing, software
##   distributed under the License is distributed on an "AS IS" BASIS,
##   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
##   See the License for the specific language governing permissions and
##   limitations under the License.

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
    agendafile = Dir[File.join(FOUNDATION_BOARD, 'board_agenda_*.txt')].sort.last.untaint
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
