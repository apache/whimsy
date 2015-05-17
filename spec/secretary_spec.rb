#
# Secretary actions
#

require_relative 'spec_helper'

feature 'report' do
  before :each do
    page.driver.header 'REMOTE_USER', 'clr'
  end

  it "should allow timestamps to be edited" do
    visit '/2015-01-21/Call-to-order'
    expect(page).to have_selector 'button', text: 'edit minutes'
  end

  it "should show minute specific options" do
    visit '/2015-02-18/January-21-2015'
    expect(page).to have_selector 'button', text: 'Cancel'
    expect(page).to have_selector 'button', text: 'Delete'
    expect(page).to have_selector 'button', text: 'Tabled'
    expect(page).to have_selector 'button', text: 'Approved'
    expect(page).to have_selector 'button', text: 'Save'
  end

  it "should prompt for action items" do
    visit '/2015-01-21/Ant'
    expect(page).to have_selector 'button', text: 'add minutes'
    expect(page).to have_selector 'option', text: 'Bertrand'
    expect(page).to have_selector 'textarea', text: 'pursue a report for Ant'
    expect(page).to have_selector 'button', text: '+ AI'
  end

  it "should show comments and edit minutes" do
    visit '/2015-02-18/Perl'
    expect(page).to have_selector 'button', text: 'edit minutes'
    expect(page).to have_selector 'h3', text: 'Comments'
    expect(page).to have_selector 'pre', text: 'sr: Reminder email sent'
    expect(page).to have_selector 'textarea', 
      text: '@Sam: Is anyone on the PMC looking at the reminders?'
    expect(page).to have_selector 'button', text: 'Delete'
  end

  it "should show vote" do
    visit '/2015-02-18/Change-MINA-Chair'
    expect(page).to have_selector 'button', text: 'vote'
    expect(page).to have_selector 'span', text: 'Reverse roll call vote'
    expect(page).to have_selector 'em', text: 'Change the Apache MINA Chair'
    expect(page).to have_selector 'button', text: 'Tabled'
    expect(page).to have_selector 'button', text: 'Unanimous'
  end

  it "should timestamp adjournment" do
    visit '/2015-02-18/Adjournment'
    expect(page).to have_selector 'button', text: 'timestamp'
  end
end
