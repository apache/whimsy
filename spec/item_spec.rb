#
# Individual report
#

require_relative 'spec_helper'

feature 'item' do
  it "should show the Secretary report" do
    visit '/2015-01-21/Secretary'

    # header
    expect(page).to have_selector '.navbar-fixed-top.available .navbar-brand', 
      text: 'Secretary'

    # info
    expect(page).to have_selector 'dd', text: '4D'
    expect(page).to have_selector 'dd', text: 'Craig'

    # content
    expect(page).to have_selector 'pre', text: /is running well/

    # footer
    expect(page).to have_selector '.backlink[href="Treasurer"]', 
     text: 'Treasurer'
    expect(page).to have_selector '.nextlink[href="Executive-Vice-President"]', 
     text: 'Executive Vice President'
  end
end
