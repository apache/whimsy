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
# Agenda parsing
#

require_relative 'spec_helper'

feature 'parse' do
  it "should parse an agenda file" do
    parsed = Agenda.parse('board_agenda_2015_01_21.txt', :quick)

    abdera = parsed.find {|item| item['title'] == 'Abdera'}
    expect(abdera[:index]).to eq("Committee Reports")

    ace = parsed.find {|item| item['title'] == 'ACE'}
    expect(ace[:attach]).to eq("C")
    expect(ace['owner']).to eq('Marcel Offermans')
    expect(ace['missing']).to equal(true)
    expect(ace['comments']).to eq('cm: Reminder email sent')
    expect(ace['shepherd']).to eq('Brett')

    avro = parsed.find {|item| item['title'] == 'Avro'}
    expect(avro[:attach]).to eq("I")
    expect(avro['owner']).to eq('Tom White')
    expect(avro['missing']).to equal(nil)
    expect(avro['comments']).to eq('')
    expect(avro['shepherd']).to eq('Chris')
    expect(avro['approved']).to include('sr')

    actions = parsed.find {|item| item['title'] == 'Action Items'}
    lenya_action = actions['actions'].find {|action| action[:pmc]=='Lenya'}
    expect(lenya_action[:owner]).to eq('Chris')
    expect(lenya_action[:text]).
      to eq('Summarize comments and follow on the dev list.')
  end
end
