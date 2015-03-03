require 'capybara/rspec'
require_relative './react_server'
require 'ruby2js/filter/react'

describe "forms", type: :feature do
  it "has an add-comment form with a disabled Save button" do
    on_react_server do
      React.render _AddComment(server: {initials: 'sr'}), document.body do
        response.end document.body.innerHTML
      end
    end

    expect(page).to have_selector '.modal#comment-form'
    expect(page).to have_selector '.modal .modal-dialog .modal-header h4',
      text: 'Enter a comment'
    expect(page).to have_selector '.modal-body input[value="sr"]'
    expect(page).to have_selector '.modal-footer button[disabled]',
      text: 'Save'
  end

  it "has an add-comment form with a disabled Save button" do
    on_react_server do
      React.render _AddComment(server: {initials: 'sr'}), document.body do
        response.end document.body.innerHTML
      end
    end

    expect(page).to have_selector '.modal#comment-form'
    expect(page).to have_selector '.modal .modal-dialog .modal-header h4',
      text: 'Enter a comment'
    expect(page).to have_selector '.modal-body input'
#   expect(page).to have_selector '.modal-body input[value="sr"]'
    expect(page).to have_selector '.modal-footer button[disabled]',
      text: 'Save'
  end

  # administrivia

  before :all do
    ReactServer.start
    Dir.chdir File.expand_path('../../views', __FILE__) do
      @script = Ruby2JS.convert(File.read('app.js.rb'), file: 'app.js.rb')
    end
  end

  before :each do
    @app, Capybara.app = Capybara.app, ReactServer.new
  end

  def on_react_server(&block)
    page.driver.post('/', @script + ';' + Ruby2JS.convert(block, react: true))
  end

  after :each do
    Capybara.app = @app
  end

  after :all do
    ReactServer.stop
  end
end
