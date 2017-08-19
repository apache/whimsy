#
# Keyboard navigation and back button
#

require_relative 'spec_helper'

feature 'navigation', js: true do
  it "should navigate to the Cocoon report and back" do
    skip "headless browser test not run on Travis" if ENV['TRAVIS']

    visit '/2015-02-18/Clerezza'
    expect(page).to have_selector '.navbar-fixed-top.reviewed .navbar-brand', 
      text: 'Clerezza'

    # Right button should advance to Cocoon report
    find('body').native.send_keys(:Right)
    expect(page).to have_selector '.navbar-fixed-top.reviewed .navbar-brand', 
      text: 'Cocoon'
    expect(page).to have_selector 'pre', 
      text: /needing board attention:\s*nothing/
    expect(page).to have_selector '.backlink[href="Clerezza"]', 
     text: 'Clerezza'
    expect(page).to have_selector '.nextlink[href="Community-Development"]', 
     text: 'Community Development'

    # Back button should return to Clerezza
    page.evaluate_script('window.history.back()')
    expect(page).to have_selector '.navbar-fixed-top.reviewed .navbar-brand', 
      text: 'Clerezza'
    expect(page).to have_selector 'pre', 
      text: /no issues requiring board attention/
    expect(page).to have_selector '.backlink[href="Chukwa"]', text: 'Chukwa'
    expect(page).to have_selector '.nextlink[href="Cocoon"]', text: 'Cocoon'
  end
end
