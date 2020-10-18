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
      text: %r{<private>\s*whisper, whisper, whisper\s*</private>}
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
    visit '/2015-02-18/ACE'

    # header
    expect(page).to have_selector '.navbar-fixed-top.reviewed .navbar-brand',
      text: 'ACE'

    # info
    expect(page).to have_selector 'dd', text: 'B'
    expect(page).to have_selector 'dd', text: 'Marcel Offermans'
    expect(page).to have_selector 'dd', text: 'Sam'
    expect(page).to have_selector 'dd', text: /, sr,/

    # content
    expect(page).to have_selector 'pre',
      text: /User reports with questions and issues about scripting/

    # no comments
    expect(page).not_to have_selector 'h4#comments', text: 'Comments'

    # footer
    expect(page).to have_selector '.backlink[href="Abdera"]',
     text: 'Abdera'
    expect(page).to have_selector 'button', text: 'add comment'
    expect(page).to have_selector 'button', text: 'approve'
    expect(page).to have_selector 'button', text: 'edit report'
    expect(page).to have_selector '.nextlink[href="ActiveMQ"]',
     text: 'ActiveMQ'

    # hidden forms
    expect(page).to have_selector '.modal .modal-dialog .modal-header h4',
      text: 'Enter a comment'
    expect(page).to have_selector 'input[id=flag][type=checkbox]'
    expect(page).to have_selector 'span', text: 'item requires discussion or follow up'
    expect(page).to have_selector '.modal .modal-dialog .modal-header h4',
      text: 'Edit Report'
    expect(page).to have_selector '#post-report-text',
      text: /Apache ACE is a software distribution framework/
    expect(page).to have_selector \
      "#post-report-message[value='Edit ACE Report']"
  end

  it "should show pending comments" do
    visit '/2015-01-21/Avro'
    expect(page).to have_selector 'h5#pending', text: 'Pending Comment'
    expect(page).to have_selector 'div.commented pre', text: 'jt: Nice report!'
    expect(page).to have_selector 'button', text: 'edit comment'
  end

  it "should show missing reports" do
    visit '/2015-02-18/DirectMemory'
    expect(page).to have_selector 'pre em', text: 'Missing'
    expect(page).not_to have_selector 'dt', text: 'Approved'

    # comments
    expect(page).to have_selector 'h4#comments', text: 'Comments'
    expect(page).to have_selector 'button', text: 'add comment'
    expect(page).not_to have_selector 'button', text: 'approve'
    expect(page).to have_selector 'pre.comment',
      text: "gs: notified. heard back already: they'll submit next month."


    # hidden forms
    expect(page).to have_selector 'button', text: 'post report'
    expect(page).to have_selector '.modal .modal-dialog .modal-header h4',
      text: 'Enter a comment'
    expect(page).to have_selector '.modal .modal-dialog .modal-header h4',
      text: 'Post Report'
    expect(page).to have_selector \
      "#post-report-message[value='Post DirectMemory Report']"
  end

  it "should show action items" do
    visit '/2015-01-21/DirectMemory'
    expect(page).to have_selector 'pre.report',
      text: '* Sam: Follow up with a more complete report next month'
    expect(page).to have_selector 'h4 a[href="Action-Items"]',
      text: 'Action Items'
  end

  it "should show draft minutes" do
    visit '/2015-02-18/Drill'

    expect(page).to have_selector 'h4', text: 'Minutes'
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
