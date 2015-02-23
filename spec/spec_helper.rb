ENV['RACK_ENV'] = 'test'
require 'capybara/rspec'
require 'capybara/poltergeist'
require_relative '../main'
Capybara.app = Sinatra::Application
Capybara.javascript_driver = :poltergeist
