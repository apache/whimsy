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

require 'whimsy/asf/agenda'
require 'date'
require 'json'

class HistoricalComments
  @@mtime = nil
  @@comments = nil

  def self.comments
    # look for agendas in the last year + half a month
    cutoff = (Date.today - 380).strftime('board_agenda_%Y_%m_%d')

    # select and sort agendas for meetings past the cutoff
    agendas = Dir[File.join(ASF::SVN['foundation_board'], '**', 'board_agenda_*')].
      select {|file| File.basename(file) > cutoff}.
      sort_by {|file| File.basename(file)}.
      map {|file| file.untaint}

    # drop latest agenda
    agendas.pop

    # return previous results unless an agenda has been updated
    mtime = agendas.map {|file| File.mtime(file)}.max
    return @@comments if mtime == @@mtime

    # initialize comments to empty hash of hashes
    comments = Hash.new {|hash, key| hash[key] = {}}

    # gather up titles and comments
    agendas.reverse.each do |agenda|
      date = agenda[/\d+_\d+_\d+/]
      begin
        ASF::Board::Agenda.parse(File.read(agenda), true).each do |report|
          next if report['comments'].to_s.empty?
          comments[report['title']][date] = report['comments']
        end
      rescue => e
        STDERR.puts e.to_s
        e.backtrace.each {|line| STDERR.puts line}
      end
    end

    # cache and return results
    @@mtime = mtime
    @@comments = comments
  end
end
