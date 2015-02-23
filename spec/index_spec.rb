require_relative 'spec_helper'

feature 'index' do
  it "should show an index page" do
    visit '/2014-03-19/'
    expect(page).to have_selector 'tr.commented td', text: 'Axis'
    expect(page).to have_selector 'tr.reviewed td', text: 'Abdera'
    expect(page).to have_selector 'tr.missing td', text: 'Click'
    expect(page).to have_selector '.backlink[href="../2014-02-19/"]', 
     text: '2014-02-19'
    expect(page).to have_selector '.nextlink[href="help"]', text: 'Help'
  end
end
