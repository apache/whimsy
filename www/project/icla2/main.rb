#!/usr/bin/env ruby

require 'sinatra'

get '/' do
  erb :index
end

# The submit button causes a POST to /answer, see below
get '/form' do
  erb :form
end

# The data from the form will be passed parameters as e.g. params[:name]
post '/answer' do
  erb :answer
end
