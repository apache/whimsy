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
