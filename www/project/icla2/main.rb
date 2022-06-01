require 'sinatra'

get '/' do
  erb :index
end

get '/form' do
  erb :form
end

post '/answer' do
  erb :answer
end
