#
# Keyboard navigation and back button
#

require_relative 'spec_helper'

if ENV['TEST_AO_PAGE'] # code to test chromedriver only
  feature 'chromedriver', js: true do
    it 'should load ASF page' do
      visit('http://apache.org')
      expect(page).to have_content('The Apache Way')
      expect(page).to have_no_content('The quick brown fox')
    end
  end
end

feature 'navigation', js: true do
  it "should navigate to the Cocoon report and back" do
    skip "headless browser test not run" if ENV['SKIP_NAVIGATION']

    visit '/2015-02-18/Clerezza'
    expect(page).to have_content('Clerezza') # basic test

    expect(page).to have_selector '.navbar-fixed-top.reviewed .navbar-brand',
      text: 'Clerezza'

    # Right button should advance to Cocoon report
    find('body').native.send_keys(:right)
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
