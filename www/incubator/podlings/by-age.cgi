#!/usr/bin/env ruby
PAGETITLE = "Incubator Podlings By Age" # Wvisible:incubator historical
$LOAD_PATH.unshift '/srv/whimsy/lib'
require 'nokogiri'
require 'date'
require 'net/http'
require 'wunderbar'
require 'wunderbar/bootstrap'
require 'whimsy/asf'

projects = URI.parse('https://incubator.apache.org/projects/')
table = Nokogiri::HTML(Net::HTTP.get(projects)).at('table')

# Hack to skip processing if cannot get the data
unless table
  _text do
    _ "Could not fetch and parse http://incubator.apache.org/projects/"
  end
  exit
end

# extract a list of [podling names, table row]
podlings = table.search('tr').map do |tr|
  tds = tr.search('td')
  next if tds.empty?
  [tds.last.text, tr]
end

# extract sorted list of durations, tally counts of podlings by years
duration = []
by_age = {}
podlings.compact.sort.each do |date, tr|
  # NOTE this makes the stats inaccurate if you don't have valid inputs
  begin
    date_started = Date.parse(date)
  rescue ArgumentError
    next
  end
  duration << Date.today - date_started
  years = (duration.last / 365.25).to_i
  by_age[years] = 1 + (by_age[years] or 0)
end

_html do
  _head_ do
    _style %{
      svg { float: right; width: 8em; height: 8em; padding-right: 5%; }
    }
  end

  _body? do
    _whimsy_body(
      title: PAGETITLE,
      related: {
        'https://incubator.apache.org/images/incubator_feather_egg_logo_sm.png' => 'Apache Incubator Egg Logo',
        'https://incubator.apache.org/' => 'Apache Incubator Homepage',
        'https://incubator.apache.org/projects/index.html' => 'List Of Incubator Podlings'
      },
      helpblock: -> {
        _ 'This shows a sorted list of all active Incubator podlings by age since joining.'
        # pie chart
        theta = 0
        colors = ['0F0', 'FF0', 'F80', 'F50', 'F00', '800']

        _svg_ viewBox: '-500 -500 1000 1000' do
          _circle r: 480, stroke: "#000", fill: "#000"
          by_age.keys.sort.each do |age|
            p1 = [Math.sin(theta)*475, -Math.cos(theta)*475].map(&:round).join(',')
            theta += Math::PI*2 * by_age[age]/duration.length
            p2 = [Math.sin(theta)*475, -Math.cos(theta)*475].map(&:round).join(',')
            _path d: "M0,0 L#{p1} A475,475 0 0 1 #{p2} Z",
              fill: "##{colors[age]}", title: "#{by_age[age]} PMCs aged " +
                "#{age} to #{age+1} year#{'s' if age>0}"
          end
        end
      }
    ) do
      # statistics
      if duration.length % 2 == 0
        mean = (duration[duration.length/2-1] + duration[duration.length/2])/2
      else
        mean = duration[duration.length/2]
      end

      _whimsy_panel_table(
        title: 'Incubator Podlings By Age',
        helpblock: -> {
          _ul do
            _li! do
              _ "Count:      #{duration.length} PPMCs ("
              _a 'history', href: 'https://projects.apache.org/'
              _ ') ('
              _a 'source data', href: 'https://incubator.apache.org/projects/#current'
              _ ')'
            end
            _li "Mean age:   #{(mean+0.5).to_i} days"
            _li "Median age: #{(duration.reduce(:+)/duration.length + 0.5).to_i} days"
            _li "Oldest podling: #{(duration.first).to_i} days"
          end
          }
      ) do
        _table.table.table_hover.table_striped do
          _tr do
            table.at('tr').search('th').each do |th|
              _th th.text
            end
          end
          podlings.compact.sort.each do |date, tr|
            _tr_ do
              tr.search('td').each do |td|
                a = td.at('a')
                if a
                  _td! {_a a.text, href: (projects + a['href']).to_s}
                else
                  _td td.text
                end
              end
            end
          end
        end
      end
    end
  end
end

