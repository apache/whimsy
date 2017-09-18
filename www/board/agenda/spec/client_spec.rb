#
# client side tests
#
# see forms_spec and filters_spec for additional client side tests
#

require_relative 'spec_helper'
require_relative 'vue_server'

describe "client", type: :feature, server: :vue do
  #
  # Agenda model
  #
  describe "agenda model" do
    it "should link pages in agenda traversal order" do
      @parsed = Agenda.parse 'board_agenda_2015_02_18.txt', :quick

      on_vue_server do

        agenda = Agenda.load(@parsed)
        container = document.createElement('div')

        class TestClient < Vue
          def render
            _div agenda do |item|
              _item.next item.next.href, class: item.href if item.next
              _item.prev item.prev.href, class: item.href if item.prev
            end
          end
        end

        Vue.renderResponse(TestClient, response)
      end

      expect(page).not_to have_selector '.Call-to-order.prev'
      expect(page).to have_selector '.Call-to-order.next', text: 'Roll-Call'
      expect(page).to have_selector '.President.next', text: 'Treasurer'
      expect(page).to have_selector '.President.prev', text: 'Chairman'
      expect(page).to have_selector '.Vice-Chairman.next', text: 'W3C-Relations'
      expect(page).to have_selector '.W3C-Relations.prev', text: 'Vice-Chairman'
      expect(page).to have_selector '.Adjournment.prev', text: 'Announcements'
      expect(page).not_to have_selector '.Adjournment.next'
    end
  end
end
