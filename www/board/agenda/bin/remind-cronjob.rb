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

#
# This is a sketch of what it would take to send board agendas via a cronjob.
#
# It currently sets @dryrun to true, preventing emails from being sent out.
#
# AGENDA_WORK is a directory that can be used to store information, depending
# on the strategy the cron job takes.
#

Dir.chdir File.expand_path('../..', __FILE__)

$LOAD_PATH.unshift '/srv/whimsy/lib'
require 'whimsy/asf/agenda'
require 'mail'
require 'listen'

FOUNDATION_BOARD = ASF::SVN['foundation_board']
AGENDA_WORK = ASF::Config.get(:agenda_work).untaint || '/srv/agenda'

require './models/agenda'

# draft reminder text
@reminder = ARGV.first || 'reminder1'
reminder = eval(File.read("views/actions/reminder-text.json.rb"))

# send reminders
@agenda = File.basename(Dir[File.join(FOUNDATION_BOARD, 'board_agenda_*.txt')].sort.last)
@from = "Whimsy <no-reply@apache.org>"
@dryrun = true
@subject = reminder[:subject]
@message = reminder[:body]
response = eval(File.read("views/actions/send-reminders.json.rb"))

# dump results for debugging purposes
puts JSON.pretty_generate(response)
