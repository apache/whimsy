#
# component tests for client side forms
#

require_relative 'spec_helper'
require_relative 'react_server'

describe "forms", type: :feature, server: :react do
  #
  # Comment form
  #
  describe "comment form" do
    it "has an add-comment form with a disabled Save button" do
      on_react_server do
        server = {pending: {}, initials: 'sr'}
        React.render _AddComment(item: {}, server: server), document.body do
          response.end document.body.innerHTML
        end
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
      on_react_server do
        server = {pending: {}, initials: 'sr'}
        React.render _AddComment(item: {}, server: server), document.body do
          node = ~'#comment_text'
          node.textContent = 'Good job!'
          Simulate.change node, target: {value: 'Good job!'}
          response.end document.body.innerHTML
        end
      end

      expect(page).to have_selector '.modal-footer .btn-warning',
        text: 'Delete'
      expect(page).to have_selector \
        '.modal-footer .btn-primary:not([disabled])', text: 'Save'
    end
  end

  #
  # Commit form
  #
  describe "commit form" do
    it "should generate a default commit message" do
      @parsed = AgendaCache.parse 'board_agenda_2015_02_18.txt', :quick
      on_react_server do
        Agenda.load(@parsed)
        server = {pending: {approved: ['7'], comments: {I: 'Nice report!'}}}
        React.render _Commit(item: {}, server: server), document.body do
          response.end document.body.innerHTML
        end
      end

      expect(page).to have_selector '#commit-text',
        text: "Approve W3C Relations\nComment on BookKeeper".gsub(/\s+/, ' ')
    end
  end
end
