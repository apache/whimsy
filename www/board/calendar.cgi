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

if CGI.new.params['format'] == ['txt']
  _text do
    @time ||= '21:30'
    @zone ||= 'UTC'
    base = TZInfo::Timezone.get(@zone)
    rotate = (@rotate || 0).to_i

    calendar.scan(pattern).flatten.each_with_index do |date, index|
      date = Date.parse(date)
      next if date <= Date.today
      time = base.local_to_utc(Time.parse("#{date}T#{@time}"))
      @time = (base.utc_to_local(time) + rotate.hour).strftime("%H:%M")
      _ '' unless index == 0
      _ time.strftime("*) %a, %d %B %Y, %H:%M UTC")
    end
  end
  exit
end

_html do
  @time ||= '21:30'
  @zone ||= 'UTC'
  base = TZInfo::Timezone.get(@zone)
  rotate = (@rotate || 0).to_i

  _h2 'Proposed board meeting times'

  _p %{
    Future meeting times, presuming that the time of the meeting is
    set to #{@time} #{@zone}, rotating each meeting time by #{rotate} hours.
  }

  if rotate == 0
    _p.bg_danger %{
      This background color indicate a local time change from the previous
      month.
    }
  end

  _table.table do
    _thead do
     _tr do
       _th
       _th 'UTC'
       _th 'Los Angeles'
       _th 'New York'
       _th 'Brussels'
       _th 'Kuala Lumpur'
       _th 'Sydney'
     end
    end

    _tbody calendar.scan(pattern).flatten do |date|
      date = Date.parse(date)
      next if date <= Date.today

      time = base.local_to_utc(Time.parse("#{date}T#{@time}"))
      @time = (base.utc_to_local(time) + rotate.hour).strftime("%H:%M")
      timeurl = 'https://www.timeanddate.com/worldclock/fixedtime.html?iso='

      _tr do
        _td date
        _td do
          _a time.strftime('%H:%M'), href: "#{timeurl}#{time.iso8601}"
        end

        zones.each do |zone|
          if zone.to_s.include? 'Asia' or zone.to_s.include? 'Europe'
            local = time.in_time_zone(zone).strftime("%H:%M")
          else
            local = time.in_time_zone(zone).strftime("%-I:%M%P")
          end

          if prev[zone] != local and prev[zone] and rotate == 0
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
