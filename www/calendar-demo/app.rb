require 'wunderbar/sinatra'
require 'wunderbar/script'
require 'ruby2js/filter/react'

require_relative 'monkey_patches'

require_relative 'model.rb'

# Redirect to this month's page
get '/' do
  today = Date.today
  redirect to("/#{today.year}/#{today.strftime('%m')}")
end

# Calendar page - html
get %r{/(\d\d\d\d)/(\d\d?)$} do |year, month|
  @year = year.to_i
  @month = month.to_i
  @items = Holiday.find(@year, @month)
  _html :calendar
end

# Calendar page - json
get %r{/(\d\d\d\d)/(\d\d?)\.json} do |year, month|
  _json do 
    Holiday.find(year.to_i, month.to_i)
  end
end
