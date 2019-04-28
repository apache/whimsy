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


$LOAD_PATH.unshift '/srv/whimsy/lib'
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
