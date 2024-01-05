#  Licensed to the Apache Software Foundation (ASF) under one or more
#  contributor license agreements.  See the NOTICE file distributed with
#  this work for additional information regarding copyright ownership.
#  The ASF licenses this file to You under the Apache License, Version 2.0
#  (the "License"); you may not use this file except in compliance with
#  the License.  You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.

if __FILE__ == $0 # This is normally done by main.rb
  require 'mustache'
  FOUNDATION_BOARD = '/srv/svn/foundation_board'
end

# simplify processing of Agenda Mustache templates
# params:
# template - the prefix name, e.g. reminder1
# context - the variable values to be used
# raise_on_context_miss - raise an Exception if any variables are missing [default true]
# returns: {subject: subject, body: body}
class AgendaTemplate
  def self.render(template, context, raise_on_context_miss=false)
    unless template =~ /\A[-\w]+\z/
      raise ArgumentError.new("Invalid template name #{template}")
    end
    m = Mustache.new
    m.template_file = File.join(FOUNDATION_BOARD, 'templates', template+'.mustache')
    m.raise_on_context_miss = raise_on_context_miss
    template = m.render(context)
    # extract subject
    subject = template[/Subject: (.*)/, 1]
    template[/Subject: .*\s+/] = ''

    # return results
    {subject: subject, body: template}
  end
end

if __FILE__ == $0
  sent_emails = []
  sent_emails << {name: 'a', emails: 'c, d'}
  sent_emails << {name: 'a', emails: 'c, d'}
  sent_emails << {name: 'a', emails: 'c, d'}
  sent_emails << {name: 'a', emails: 'c, d'}
  view = {meeting: 'meeting', agenda: 'board_agenda_2024_01_17.txt', unsent: ['a', 'b', 'c'], sent_emails: sent_emails}
  render = AgendaTemplate.render('reminder-summary',view, true)
  puts render[:subject]
  puts render[:body]
end
