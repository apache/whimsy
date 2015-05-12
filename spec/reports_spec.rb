#
# Individual report pages (e.g., for PMCs)
#

require_relative 'spec_helper'

feature 'report' do
  it "should show the President report" do
    visit '/2015-02-18/President'

    # header
    expect(page).to have_selector '.navbar-fixed-top.available .navbar-brand', 
      text: 'President'
    expect(page).to have_selector '#info'

    # body 
    expect(page).to have_selector 'pre', 
      text: 'Sally produced our first quarterly report'
    expect(page).to have_selector '.private',
      %r{<private>\s*whisper, whisper, whisper\s*</private>}
    expect(page).to have_selector 'a[href="Executive-Assistant"]', 
     text: 'Executive Assistant'
    expect(page).to have_selector '.pres-missing[href="Travel-Assistance"]', 
     text: 'Travel Assistance'

    # footer
    expect(page).to have_selector '.backlink[href="Chairman"]',
      text: 'Chairman'
    expect(page).to have_selector 'button', text: 'add comment'
    expect(page).to have_selector 'button', text: 'edit report'
    expect(page).to have_selector '.nextlink[href="Treasurer"]', 
     text: 'Treasurer'
  end

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
    expect(page).to have_selector 'button', text: 'approve'
    expect(page).to have_selector 'button', text: 'edit report'
    expect(page).to have_selector '.nextlink[href="Axis"]', 
     text: 'Axis'

    # pending comments
    expect(page).to have_selector 'h3#comments', text: 'Pending Comment'
    expect(page).to have_selector 'pre.comment', text: 'jt: Nice report!'

    # hidden forms
    expect(page).to have_selector '.modal .modal-dialog .modal-header h4',
      text: 'Edit comment'
    expect(page).to have_selector '.modal .modal-dialog .modal-header h4',
      text: 'Edit Report'
    expect(page).to have_selector '#post-report-text',
      text: 'Apache Avro is a cross-language data serialization system.'
    expect(page).to have_selector \
      "#post-report-message[value='Edit Avro Report']"
  end

  it "should show missing reports" do
    visit '/2015-02-18/Tuscany'
    expect(page).to have_selector 'pre em', text: 'Missing'
    expect(page).not_to have_selector 'dt', text: 'Approved'

    # comments
    expect(page).to have_selector 'h3#comments', text: 'Comments'
    expect(page).to have_selector 'button', text: 'add comment'
    expect(page).not_to have_selector 'button', text: 'approve'
    expect(page).to have_selector 'pre.comment', text: 'cm: Reminder email sent'

    # action items
    expect(page).to have_selector 'h3 a[href="Action-Items"]',
      text: 'Action Items'
    expect(page).to have_selector 'button', text: 'post report'
    expect(page).to have_selector 'pre.report', 
      text: '* Greg: Is it time to retire the project?'

    # hidden forms
    expect(page).to have_selector '.modal .modal-dialog .modal-header h4',
      text: 'Enter a comment'
    expect(page).to have_selector '.modal .modal-dialog .modal-header h4',
      text: 'Post Report'
    expect(page).to have_selector \
      "#post-report-message[value='Post Tuscany Report']"
  end

  it "should show draft minutes" do
    visit '/2015-02-18/Drill'

    expect(page).to have_selector 'h3', text: 'Minutes'
    expect(page).to have_selector 'pre', 
      text: '@Brett: Are hangouts documents so non-attendees can participate later'
  end


  it "should show reports with warnings" do
    visit '/2015-01-21/Change-Labs-Chair'

    expect(page).to have_selector '.navbar-fixed-top.missing .navbar-brand', 
      text: 'Change Labs Chair'
    expect(page).to have_selector 'ul.missing li', 
      text: 'Heading is not indented 4 spaces'
  end
end
