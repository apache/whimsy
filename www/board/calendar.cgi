#!/usr/bin/env ruby
$LOAD_PATH.unshift '/srv/whimsy/lib'
require 'whimsy/asf'
require 'wunderbar/bootstrap'
require 'active_support/time'
require 'date'

calendar = IO.read("#{ASF::SVN['board']}/calendar.txt")
pattern = /\s*\*\) (.*),/

zones = [
  TZInfo::Timezone.get('America/Los_Angeles'),
  TZInfo::Timezone.get('America/New_York'),
  TZInfo::Timezone.get('Europe/Brussels'),
  TZInfo::Timezone.get('Asia/Kuala_Lumpur'),
  TZInfo::Timezone.get('Australia/Sydney')
]


prev = {}

_html do
  @time ||= '21:30'
  @zone ||= 'UTC'
  base = TZInfo::Timezone.get(@zone)

  _h2 'Proposed board meeting times'

  _p %{
    Future meeting times, presuming that the time of the meeting is
    set to #{@time} #{@zone}.
  }
  
  _p.bg_danger %{
    This background color indicate a local time change from the previous
    month.
  }
  
  _table.table do
    _thead do
     _tr do
       _th
       _th 'Los Angeles'
       _th 'New York'
       _th 'Brussels'
       _th 'Kuala Lumpur '
       _th 'Sydney'
     end
    end

    _tbody calendar.scan(pattern).flatten do |date|
      date = Date.parse(date)
      next if date < Date.today

      time = base.local_to_utc(Time.parse("#{date}/#{@time}"))

      _tr do
        _td date
        zones.each do |zone|
          local = time.in_time_zone(zone).strftime("%H:%M")
          if prev[zone] != local and prev[zone]
            _td.bg_danger local
          else
            _td local
          end
          prev[zone] = local
        end
      end
    end
  end
end
