#
# Individual report
#

require_relative 'spec_helper'

feature 'report' do
  it "should show the Avro report" do
    visit '/2015-01-21/Avro'

    # header
    expect(page).to have_selector '.navbar-fixed-top.reviewed .navbar-brand', 
      text: 'Avro'

    # info
    expect(page).to have_selector 'dd', text: 'I'
    expect(page).to have_selector 'dd', text: 'Tom White'
    expect(page).to have_selector 'dd', text: 'Chris'
    expect(page).to have_selector 'dd', text: /, sr,/

    # content
    expect(page).to have_selector 'pre', 
      text: /no issues that require the board's attention/

    # footer
    expect(page).to have_selector '.backlink[href="Attic"]', 
     text: 'Attic'
    expect(page).to have_selector '.nextlink[href="Axis"]', 
     text: 'Axis'
  end

  it "should show missing reports" do
    visit '/2015-02-18/Abdera'
    expect(page).to have_selector 'pre em', text: 'Missing'
    expect(page).not_to have_selector 'dt', text: 'Approved'
  end
end
