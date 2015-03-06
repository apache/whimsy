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

    # no comments
    expect(page).not_to have_selector 'h3#comments', text: 'Comments'

    # footer
    expect(page).to have_selector '.backlink[href="Attic"]', 
     text: 'Attic'
    expect(page).to have_selector 'button', text: 'edit comment'
    expect(page).to have_selector '.nextlink[href="Axis"]', 
     text: 'Axis'

    # pending comments
    expect(page).to have_selector 'h3#comments', text: 'Pending Comment'
    expect(page).to have_selector 'pre.comment', text: 'jt: Nice report!'

    # hidden form
    expect(page).to have_selector '.modal .modal-dialog .modal-header h4',
      text: 'Edit comment'
  end

  it "should show missing reports" do
    visit '/2015-02-18/Tuscany'
    expect(page).to have_selector 'pre em', text: 'Missing'
    expect(page).not_to have_selector 'dt', text: 'Approved'

    # comments
    expect(page).to have_selector 'h3#comments', text: 'Comments'
    expect(page).to have_selector 'button', text: 'add comment'
    expect(page).to have_selector 'pre.comment', text: 'cm: Reminder email sent'

    # action items
    expect(page).to have_selector 'h3', text: 'Action Items'
    expect(page).to have_selector 'pre.comment', 
      text: 'Greg: Is it time to retire the project?'

    # hidden form
    expect(page).to have_selector '.modal .modal-dialog .modal-header h4',
      text: 'Enter a comment'
  end
end
