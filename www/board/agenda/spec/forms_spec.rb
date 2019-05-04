##   Licensed to the Apache Software Foundation (ASF) under one or more
##   contributor license agreements.  See the NOTICE file distributed with
##   this work for additional information regarding copyright ownership.
##   The ASF licenses this file to You under the Apache License, Version 2.0
##   (the "License"); you may not use this file except in compliance with
##   the License.  You may obtain a copy of the License at
## 
##       http://www.apache.org/licenses/LICENSE-2.0
## 
##   Unless required by applicable law or agreed to in writing, software
##   distributed under the License is distributed on an "AS IS" BASIS,
##   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
##   See the License for the specific language governing permissions and
##   limitations under the License.

#
# component tests for client side forms
#

require_relative 'spec_helper'
require_relative 'vue_server'

describe "forms", type: :feature, server: :vue do
  #
  # Comment form
  #
  describe "comment form" do
    it "has an add-comment form with a disabled Save button" do
      on_vue_server do
        class TestCommentForm < Vue
          def render
            _AddComment(item: {}, server: {pending: {}, initials: 'sr'})
          end
        end

        Vue.renderResponse(TestCommentForm, response)
      end

      expect(page).to have_selector '.modal#comment-form'
      expect(page).to have_selector '.modal .modal-dialog .modal-header h4',
        text: 'Enter a comment'
      expect(page).to have_selector '.modal-body input[value="sr"]'
      expect(page).not_to have_selector '.modal-footer .btn-warning',
        text: 'Delete'
      expect(page).to have_selector '.modal-footer .btn-primary[disabled]',
        text: 'Save'
    end

    it "should enable Save button after input" do
      on_vue_server do
        item = {}
        server = {pending: {}, initials: 'sr'}

        class TestCommentForm < Vue
          def render
            _AddComment(item: item, server: server)
          end
        end

        app = Vue.renderApp(TestCommentForm)
        node = app.querySelector('#comment-text')
        node.value = 'Good job!'
        node.dispatchEvent(Event.new('input'))
        Vue.nextTick { response.end app.outerHTML }
      end

      expect(page).to have_selector '.modal-footer .btn-warning', text: 'Delete'
      expect(page).to have_selector \
        '.modal-footer .btn-primary:not([disabled])', text: 'Save'
    end
  end

  #
  # Post form
  #
  describe "post form" do
    it "should indicate when a reflow is needed" do
      parsed = Agenda.parse 'board_agenda_2015_02_18.txt', :quick
      @item = parsed.find {|item| item['title'] == 'Executive Vice President'}
      on_vue_server do
        item = Agenda.new(@item)

        class TestPostForm < Vue
          def render
            _Post(item: item, button: 'edit report')
          end
        end

        Vue.renderResponse(TestPostForm, response)
      end

      expect(find('#post-report-text').value).to match(/to answer\nquestions/)
      expect(page).to have_selector '.modal-footer .btn-danger',
        text: 'Reflow'
    end

    it "should perform a reflow" do
      parsed = Agenda.parse 'board_agenda_2015_02_18.txt', :quick
      @item = parsed.find {|item| item['title'] == 'Executive Vice President'}
      on_vue_server do
        item = Agenda.new(@item)

        class TestPost < Vue
          def render
            _Post(item: item, button: 'edit report')
          end
        end

        app = Vue.renderApp(TestPost)
        button = app.querySelector('.btn-danger')
        button.dispatchEvent(Event.new('click'))
        Vue.nextTick { response.end app.outerHTML }
      end

      expect(find('#post-report-text').value).to match(/to\nanswer questions/)
      expect(page).to have_selector '.modal-footer .btn-default',
        text: 'Reflow'
    end
  end

  #
  # Commit form
  #
  describe "commit form" do
    it "should generate a default commit message" do
      @parsed = Agenda.parse 'board_agenda_2015_02_18.txt', :quick
      on_vue_server do
        Agenda.load(@parsed)
        server = {pending: {approved: ['7'], comments: {I: 'Nice report!'}}}

        class TestCommit < Vue
          def render
            _Commit(item: {}, server: server)
          end
        end

        Vue.renderResponse TestCommit, response
      end

      expect(page).to have_selector '#commit-text',
        text: "Approve W3C Relations\nComment on BookKeeper".gsub(/\s+/, ' ')
    end
  end
end
