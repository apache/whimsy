require_relative 'spec_helper'

feature 'static rendering' do
  it 'should show Feb 2015' do
    visit '/2015/02'

    expect(page).to have_selector 'header', text: 'February 2015'
    expect(page).to have_selector 'li', text: "Valentine's Day"
  end
end
