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

  it "should support queued/pending approvals and comments" do
    visit '/2015-02-18/queue'

    expect(page).to have_selector 'a[href="queue/W3C-Relations"]', 
      text: 'W3C Relations'
    expect(page).to have_selector 'a[href="queue/Celix"]', 
      text: 'Celix'
    expect(page).to have_selector 'dt a[href="BookKeeper"]', text: 'BookKeeper'
    expect(page).to have_selector 'dd p', text: 'Nice report!'
  end

  it "should follow the ready queue" do
    visit '/2015-01-21/queue/Onami'

    expect(page).to have_selector '.navbar-fixed-top.commented .navbar-brand', 
      text: 'Onami'

    expect(page).to have_selector '.backlink[href="queue/MyFaces"]',
      text: 'MyFaces'
    expect(page).to have_selector '.nextlink[href="queue/OpenOffice"]',
      text: 'OpenOffice'
  end

  it "should show shepherd reports" do
    visit '/2015-01-21/shepherd/Sam'

    expect(page).to have_selector 'h3.commented a[href="shepherd/queue/Flink"]',
      text: 'Flink'
    expect(page).to have_selector 'h4', text: 'Comments'
    expect(page).to have_selector 'pre.comment span', 
      text: 'cm: great report!'
    expect(page).to have_selector 'h4', text: 'Action Items'
    expect(page).to have_selector 'pre.comment', 
      text: 'Chris: Please clarify what "voted on" means'
  end

  it "should follow the shepherd queue" do
    visit '/2015-02-18/shepherd/queue/Hama'

    expect(page).to have_selector '.navbar-fixed-top.missing .navbar-brand', 
      text: 'Hama'

    expect(page).to have_selector '.backlink[href="shepherd/queue/Forrest"]',
      text: 'Forrest'
    expect(page).to have_selector '.nextlink[href="shepherd/queue/Mesos"]',
      text: 'Mesos'
  end

  it "should highlight and crosslink action items" do
    visit '/2015-02-18/Action-Items'

    expect(page).to have_selector 'span.commented', text: /^\s*Status:$/
    expect(page).to have_selector 'a.missing[href=Deltacloud]',
      text: '[ Deltacloud ]'
    expect(page).to have_selector 'a.reviewed[href=ACE]', text: '[ ACE ]'
    expect(page).to have_selector '.backlink[href="Discussion-Items"]',
      text: 'Discussion Items'
    expect(page).to have_selector '.nextlink[href="Unfinished-Business"]',
      text: 'Unfinished Business'
    expect(page).to have_selector 'a[href="http://s.apache.org/jDZ"]'
  end

  it "should hypertext minutes" do
    visit '/2015-02-18/January-21-2015'

    expect(page).to have_selector \
     'a[href="https://svn.apache.org/repos/private/foundation/board/board_minutes_2015_01_21.txt"]',
     text: 'board_minutes_2015_01_21.txt'
  end
end
