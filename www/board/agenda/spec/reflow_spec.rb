#
# component tests for client side forms
#

require_relative 'spec_helper'
require_relative 'vue_server'

describe "reflow", type: :feature, server: :vue do
  #
  # Comment form
  #
  describe "incubator rules" do
    it "handles ordered lists" do
      on_vue_server do
        class TestReflow < Vue
          def render
            _ Flow.text("1. a\n2. b")
          end
        end

        Vue.renderResponse(TestReflow, response)
      end

      expect(page.body).to eq "1. a\n2. b"
    end

    it "handles questions and colons" do
      on_vue_server do
        class TestReflow < Vue
          def render
            _ Flow.text("a?\nb:\nc", '', true)
          end
        end

        Vue.renderResponse(TestReflow, response)
      end

      expect(page.body).to eq "a?\nb:\nc"
    end

    it "leaves long URLs alone" do
      @line = "[7] http://example.com" + "/foobar" * 12

      on_vue_server do
        line = @line

        class TestReflow < Vue
          def render
            _ Flow.text(line)
          end
        end

        Vue.renderResponse(TestReflow, response)
      end

      expect(page.body).to eq @line
    end
  end
end
