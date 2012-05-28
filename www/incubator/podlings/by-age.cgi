#!/usr/bin/ruby1.9.1
require 'nokogiri'
require 'date'
require 'net/http'
require 'wunderbar'

projects = URI.parse('http://incubator.apache.org/projects/')
table = Nokogiri::HTML(Net::HTTP.get(projects)).at('table')

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
  duration << Date.today - Date.parse(date)
  years = (duration.last / 365.25).to_i
  by_age[years] = 1 + (by_age[years] or 0)
end

_html do
  _head_ do
    _meta charset: 'utf=8'
    _title 'Incubated Projects - Apache Incubator'
    _link rel: "stylesheet", type: 'text/css',
      href: "http://incubator.apache.org/style/bootstrap-1-3-0-min.css"
    _link rel: "stylesheet", type: 'text/css',
      href: "http://incubator.apache.org/style/style.css"
    _style %{
      svg { float: right; width: 8em; height: 8em; padding-right: 5%; }
      body { margin: 0 2em }
    }
  end

  _body? do
    # Standard Incubator header
    _div.container do
      _div.row do
        _div.span12 do
          _a href: "http://www.apache.org/" do
            _img alt: "The Apache Software Foundation", border: "0",
              src: "http://www.apache.org/images/asf_logo_wide.gif"
          end
        end
        _div.span4 do
          _a href: "http://incubator.apache.org/" do
            _img alt: "Apache Incubator", border: "0",
              src: "http://incubator.apache.org/images/apache-incubator-logo.png"
          end
        end
      end

      _div.row do
        _div.span16 do
          _hr noshade: 'noshade', size: '1'
        end
      end
    end

    # pie chart
    theta = 0
    colors = ['0F0', 'FF0', 'F80', 'F50', 'F00']

    _svg_ viewBox: '-500 -500 1000 1000' do
      _circle r: 480, stroke: "#000", fill: "#000"
      by_age.keys.sort.each do |age|
        p1 = [Math.sin(theta)*475, -Math.cos(theta)*475].map(&:round).join(',')
        theta += Math::PI*2 * by_age[age]/duration.length
        p2 = [Math.sin(theta)*475, -Math.cos(theta)*475].map(&:round).join(',')
        _path d: "M0,0 L#{p1} A475,475 0 0 1 #{p2} Z", 
          fill: '#' + colors[age], title: "#{by_age[age]} PMCs aged " +
            "#{age} to #{age+1} year#{'s' if age>0}"
      end
    end

    # statistics
    if duration.length % 2 == 0
      mean = (duration[duration.length/2-1] + duration[duration.length/2])/2
    else
      mean = duration[duration.length/2]
    end

    _h2 'Statistics'
    _p! do
      _ "Count:      #{duration.length} PPMCs ("
      _a 'history', href: 'http://incubator.apache.org/history/'
      _ ")"
    end
    _p "Mean age:   #{(mean+0.5).to_i} days"
    _p "Median age: #{(duration.reduce(:+)/duration.length + 0.5).to_i} days"

    # Sorted list of podlings
    _h2_! do
      _a 'Currently in incubation',
       href: 'http://incubator.apache.org/projects/#current'
      _ ', sorted by age'
    end

    _table do
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
