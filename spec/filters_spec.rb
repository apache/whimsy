require_relative './react_server'

describe "filters", type: :feature, server: :react do
  before :all do
    @parsed = AgendaCache.parse 'board_agenda_2015_02_18.txt', :quick
  end

  #
  # convert strings containing http:// in reports to links
  #
  describe "hotlink" do
    it "should convert http addresses to links" do
      @item = @parsed.find {|item| item['title'] == 'Clerezza'}

      on_react_server do
        React.render _Report(item: Agenda.new(@item)), document.body do
          response.end document.body.innerHTML
        end
      end

      expect(page).to have_selector 'a[href="http://s.apache.org/EjO"]'
    end
  end

  #
  # add local time to Call to order
  #
  describe "local time" do
    it "should convert start time to local time on call to order" do
      @item = @parsed.find {|item| item['title'] == 'Call to order'}

      on_react_server do
        React.render _Report(item: Agenda.new(@item)), document.body do
          response.end document.body.innerHTML
        end
      end

      expect(page).to have_selector 'span.hilite', text: /Local Time:/
    end
  end
end
