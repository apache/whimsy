require_relative '../asf'
require 'tzinfo'

module ASF
  module Board
    TIMEZONE = TZInfo::Timezone.get('US/Pacific')

    # return list of board meeting times as listed in 
    # committers/board/calendar.txt
    def self.calendar
      svn = ASF::SVN['private/committers/board']
      txt = File.read("#{svn}/calendar.txt")
      times = txt.scan(/^\s+\*\)\s(.*)/).flatten
      times.map {|time| TIMEZONE.local_to_utc(Time.parse(time))}
    end

    # return time of next meeting
    def self.nextMeeting
      self.calendar.select {|time| time > Time.now.utc}.min
    end
  end
end
