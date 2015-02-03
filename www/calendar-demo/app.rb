require 'wunderbar/sinatra'
require 'wunderbar/script'
require 'ruby2js/filter/react'

require_relative 'monkey_patches'

require_relative 'model.rb'

# Main HTML
get '/' do
  today = Date.today
  redirect to("/#{today.year}/#{today.strftime('%m')}")
end

get %r{/(\d\d\d\d)/(\d\d?)$} do |year, month|
  @year = year.to_i
  @month = month.to_i
  @items = Holiday.find(@year, @month)
  _html :calendar
end

get %r{/(\d\d\d\d)/(\d\d?)\.json} do |year, month|
  _json do 
    Holiday.find(year.to_i, month.to_i)
  end
end

# React components
get %r{^/([-\w]+)\.js$} do |script|
  _js :"#{script}"
end
