#
# Other views
#

require_relative 'spec_helper'

feature 'other reports' do
  it "should support search" do
    visit '/2015-02-18/search?q=ruby'

    expect(page).to have_selector 'pre', text: 'Sam Ruby'
    expect(page).to have_selector 'h4 a', text: 'Qpid'
  end

  it "should support comments" do
    visit '/2015-02-18/comments'

    expect(page).to have_selector 'h4 a', text: 'Hama'
    expect(page).to have_selector 'pre', text: 'sr: Reminder email sent'
  end
end
