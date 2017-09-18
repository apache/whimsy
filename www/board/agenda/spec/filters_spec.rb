require_relative 'spec_helper'
require_relative 'vue_server'

describe "filters", type: :feature, server: :vue do
  before :all do
    @parsed = Agenda.parse 'board_agenda_2015_02_18.txt', :quick
  end

  #
  # convert strings containing http:// in reports to links
  #
  describe "hotlink" do
    it "should convert http addresses to links" do
      @item = @parsed.find {|item| item['title'] == 'Clerezza'}

      on_vue_server do
        agenda_item = Agenda.new(@item)

        class TestReport < Vue
          def render
            _Report item: agenda_item
          end
        end

        Vue.renderResponse TestReport, response
      end

      expect(page).to have_selector 'a[href="http://s.apache.org/EjO"]'
    end
  end

  #
  # add local time to Call to order
  #
  describe "call to order" do
    it "should convert start time to local time on call to order" do
      @item = @parsed.find {|item| item['title'] == 'Call to order'}

      on_vue_server do
        agenda_item = Agenda.new(@item)

        class TestReport < Vue
          def render
            _Report item: agenda_item
          end
        end

        Vue.renderResponse TestReport, response
      end

      expect(page).to have_selector 'span.hilite', text: /Local Time:/
    end
  end

  #
  # link names to roster
  #
  describe "roll call" do
    it "should link people to roster info" do
      @item = @parsed.find {|item| item['title'] == 'Roll Call'}
      @item['people'].replace({
        rubys: {name: "Sam Ruby", member: true, attending: true}
      })

      on_vue_server do
        agenda_item = Agenda.new(@item)

        class TestReport < Vue
          def render
            _Report item: agenda_item
          end
        end

        Vue.renderResponse TestReport, response
      end

      expect(page).to have_selector \
        'a[href="/roster/committer/rubys"]'
      expect(page).to have_selector 'b', text: 'Sam Ruby'
      expect(page).to have_selector 'a.commented', text: 'Greg Stein'
    end
  end
end
