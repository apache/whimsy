#
# Index page
#

require_relative 'spec_helper'

feature 'index' do
  it "should show an index page - without an index page" do
    visit '/2015-02-18/'

    # header
    expect(page).to have_selector '.navbar-fixed-top.blank .navbar-brand',
      text: '2015-02-18'
    expect(page).not_to have_selector '.navbar-fixed-top .label-danger a'
    expect(page).to have_selector '#agenda', text: 'Agenda'

    # navigation
    expect(page).to have_selector 'a[href=Change-Geronimo-Chair]',
      text: 'Special Orders'

    # rows with colors and titles
    expect(page).to have_selector 'tr.missing td', text: 'Abdera'
    expect(page).to have_selector 'tr.reviewed td', text: 'Buildr'
    expect(page).to have_selector 'tr.reviewed td', text: 'Celix'
    expect(page).to have_selector 'tr.commented td', text: 'Lenya'

    # attach, owner, shepherd columns
    expect(page).to have_selector 'tr.reviewed td', text: 'CF'
    expect(page).to have_selector 'tr.reviewed td', text: 'Mark Cox'
    expect(page).to have_selector 'tr.missing td', text: 'Sam'
    expect(page).to have_selector 'tr[10] td[2]', text: 'Executive Assistant'
    expect(page).to have_selector 'tr[10] td[4]', text: 'Ross'

    # links
    expect(page).to have_selector 'a[href=ACE]', text: 'ACE'

    # footer
    expect(page).to have_selector '.backlink[href="../2015-01-21/"]',
     text: '2015-01-21'
    expect(page).to have_selector 'button', text: 'refresh'
    expect(page).to have_selector 'button', text: 'add item'
    expect(page).to have_selector '.nextlink[href="help"]', text: 'Help'

    # hidden form
    expect(page).to have_selector '.modal .modal-dialog .modal-header h4',
      text: 'Select Item Type'
  end

  it "should show an index page - with pending changes" do
    visit '/2015-01-21/'

    # header
    expect(page).to have_selector '.navbar-fixed-top.blank .navbar-brand',
      text: '2015-01-21'
    expect(page).to have_selector '.navbar-fixed-top .label-danger a',
      text: '5'

    # footer
    expect(page).to have_selector '.nextlink[href="../2015-02-18/"]',
     text: '2015-02-18'
    expect(page).to have_selector 'button', text: 'refresh'
    expect(page).to have_selector 'button', text: 'add item'
    expect(page).to have_selector '.backlink[href="help"]', text: 'Help'
  end


  it "should show a summary" do
    visit '/2015-02-18/'

    expect(page).to have_selector 'tr.available td', text: '84' # committee
    expect(page).to have_selector 'tr.available td', text: '6'  # special
    expect(page).to have_selector 'tr.ready td', text: '2'
    expect(page).to have_selector 'tr.commented td', text: '1'
    expect(page).to have_selector 'tr.missing td', text: '19'
  end
end
