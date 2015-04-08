#
# Agenda parsing
#

require_relative 'spec_helper'

feature 'parse' do
  it "should parse an agenda file" do
    parsed = AgendaCache.parse('board_agenda_2015_02_18.txt', :quick)

    abdera = parsed.find {|item| item['title'] == 'Abdera'}
    expect(abdera[:attach]).to eq("A")
    expect(abdera['owner']).to eq('Ant Elder')
    expect(abdera['missing']).to equal(true)
    expect(abdera['comments']).to eq('rb: Reminder email sent')
    expect(abdera['shepherd']).to eq('Rich')
    expect(abdera[:index]).to eq("Committee Reports")

    aries = parsed.find {|item| item['title'] == 'Aries'}
    expect(aries[:attach]).to eq("G")
    expect(aries['owner']).to eq('Jeremy Hughes')
    expect(aries['missing']).to equal(nil)
    expect(aries['comments']).to eq('')
    expect(aries['shepherd']).to eq('Jim')
    expect(aries['approved']).to include('sr')

    actions = parsed.find {|item| item['title'] == 'Action Items'}
    expect(actions['actions']['Rave']).to include(/Sam:/)
  end
end
