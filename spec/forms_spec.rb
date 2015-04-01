#
# component tests for client side forms
#

require 'capybara/rspec'
require_relative './react_server'
require 'ruby2js/filter/react'

describe "forms", type: :feature do
  #
  # Comment form
  #
  describe "comment form" do
    it "has an add-comment form with a disabled Save button" do
      @foo = 'bar'
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
      @parsed = AgendaCache.parse 'board_agenda_2015_02_18.txt', :full
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

  #
  # administrivia
  #
  before :all do
    ReactServer.start
    Dir.chdir File.expand_path('../../views', __FILE__) do
      @_script = Ruby2JS.convert(File.read('app.js.rb'), file: 'app.js.rb')
    end
  end

  before :each do
    @_app, Capybara.app = Capybara.app, ReactServer.new
  end

  def on_react_server(&block)
    locals = {}
    instance_variables.each do |ivar|
      next if ivar.to_s.start_with? '@_'
      locals[ivar] = instance_variable_get(ivar)
    end

    page.driver.post('/', @_script + ';' +
      Ruby2JS.convert(block, react: true, ivars: locals))
  end

  after :each do
    Capybara.app = @_app
  end

  after :all do
    ReactServer.stop
  end
end
