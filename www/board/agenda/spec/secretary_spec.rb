#
# Secretary actions
#

require_relative 'spec_helper'

feature 'report' do
  before :each do
    page.driver.header 'REMOTE_USER', 'mattsicker' # must be a non-director member of the secretarial team
  end

  it "should allow timestamps to be edited" do
    visit '/2015-02-18/Call-to-order'
    expect(page).to have_selector 'button', text: 'edit minutes'
  end

  it "should take roll" do
    visit '/2015-02-18/Roll-Call'
    expect(page).to have_selector('h3', text: 'Directors')
    expect(page).to have_selector('a', text: 'Sean Kelly')
    expect(page).to have_selector('a', text: 'Mark Radcliffe')
    expect(page).to have_selector('input[value="joined at 10:55"]')
    expect(page).to have_selector('h3', text: 'Minutes')
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
    visit '/2015-02-18/Hama'
    expect(page).to have_selector 'button', text: 'add minutes'
    expect(page).to have_selector 'option', text: 'Sam'
    expect(page).to have_selector 'textarea', text: 'pursue a report for Hama'
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

  it "should draft minutes" do
    completed '2015-02-18' do
      visit '/2015-02-18/Adjournment'
      expect(page).not_to have_selector 'button', text: 'timestamp'
      expect(page).to have_selector 'button', text: 'edit minutes'
      expect(page).to have_selector 'button', text: 'draft minutes'

      draft = page.driver.get('/text/draft/2015_02_18').body
      expect(draft).to include('Board of Directors Meeting Minutes')
      expect(draft).to include('was scheduled')
      expect(draft).to include('was held')
      expect(draft).to match(/began at \d+:\d\d/)
      expect(draft).to include('was used for backup purposes')
      expect(draft).to include('Directors Present')
      expect(draft).to include('Published minutes can be found at')
      expect(draft).to include('approved as submitted by General Consent.')
      expect(draft).to include('@Sam: Is anyone on the PMC looking at the reminders?')
      expect(draft).to include('No report was submitted.')
      expect(draft).to include('was approved by Unanimous Vote of the directors present.')
      expect(draft).to match(/Adjourned at \d+:\d\d UTC/)

      @agenda = 'board_agenda_2015_02_18.txt'
      @message = 'Draft minutes for 2015-02-18'
      @text = draft

      eval(File.read('views/actions/draft.json.rb'), nil, 'draft.json.rb')

      minutes = @agenda.sub('_agenda_', '_minutes_')
      expect(@commits).to include(minutes)
      expect(@commits[minutes]).to eq draft
    end
  end

  it "should publish minutes" do
    visit '/2015-01-21/'
    expect(page).to have_selector 'textarea', text:
      '[21 January 2015](../records/minutes/2015/board_minutes_2015_01_21.txt)'
    expect(page).to have_selector 'textarea', text:
      '* Establish Samza'
    expect(page).to have_selector 'textarea', text:
      '* Change ZooKeeper Chair'
    expect(page).to have_selector \
      'input#message[value="Publish 21 January 2015 minutes"]'
  end

  def completed(meeting, &block)
    file = "#{AGENDA_WORK}/board_minutes_#{meeting.gsub('-', '_')}.yml"
    minutes = IO.read(file)
    timestamp = Time.now.gmtime.to_f * 1000
    IO.write file, YAML.dump(YAML.safe_load(minutes, permitted_classes: [Symbol]).
      merge('complete' => timestamp, 'Adjournment' => '11:45'))
    yield
  ensure
    IO.write file, minutes
  end

  # sinatra environment
  def env
    Struct.new(:user, :password).new('test', nil)
  end
end
