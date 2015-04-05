require_relative './react_server'

describe "filters", type: :feature, server: :react do
  #
  # Comment form
  #
  describe "hotlink" do
    it "should convert http addresses to links" do
      @parsed = AgendaCache.parse 'board_agenda_2015_02_18.txt', :quick
      @item = @parsed.find {|item| item['title'] == 'Clerezza'}

      on_react_server do
        React.render _Report(item: Agenda.new(@item)), document.body do
          response.end document.body.innerHTML
        end
      end

      expect(page).to have_selector 'a[href="http://s.apache.org/EjO"]'
    end
  end
end
