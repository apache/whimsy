require_relative 'spec_helper'

feature 'navigation', js: true do
  it "should navigate to the Executive Vice President report" do
    visit '/2014-02-19/Secretary'
    expect(page).to have_selector '.navbar-fixed-top .navbar-brand', 
      text: 'Secretary'

    find('body').native.send_keys(:Right)
    expect(page).to have_selector '.navbar-fixed-top .navbar-brand', 
      text: 'Executive Vice President'
    expect(page).to have_selector 'pre', text: /venues in Europe/
    expect(page).to have_selector '.backlink[href="Secretary"]', 
     text: 'Secretary'
    expect(page).to have_selector '.nextlink[href="Vice-Chairman"]', 
     text: 'Vice Chairman'

    page.evaluate_script('window.history.back()')
    expect(page).to have_selector '.navbar-fixed-top .navbar-brand', 
      text: 'Secretary'
    expect(page).to have_selector 'pre', text: /December doldrums/
    expect(page).to have_selector '.backlink[href="Treasurer"]', 
     text: 'Treasurer'
    expect(page).to have_selector '.nextlink[href="Executive-Vice-President"]', 
     text: 'Executive Vice President'
  end
end
