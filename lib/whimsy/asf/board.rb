require_relative '../asf'
require 'tzinfo'

module ASF
  module Board
    TIMEZONE = TZInfo::Timezone.get('US/Pacific')

    # sorted list of Directors
    def self.directors
      ASF::Service['board'].members.
        map {|person| person.public_name}.
        sort_by {|name| name.split(' ').rotate}
    end

    # list of board meeting times as listed in 
    # committers/board/calendar.txt
    def self.calendar
      svn = ASF::SVN['private/committers/board']
      txt = File.read("#{svn}/calendar.txt")
      times = txt.scan(/^\s+\*\)\s(.*)/).flatten
      times.map {|time| TIMEZONE.local_to_utc(Time.parse(time))}
    end

    # time of next meeting
    def self.nextMeeting
      time = self.calendar.select {|time| time > Time.now.utc}.min

      if not time
        require 'chronic'
        time ||= Chronic.parse('3rd wednesday this month')
        time = Chronic.parse('3rd wednesday next month') if time < Time.now.utc
      end

      time
    end

    # list of PMCs reporting in the specified meeting
    def self.reporting(meeting)
      month = meeting.strftime('%B')
      ASF::Committee.load_committee_info
      ASF::Committee.pmcs.select do |pmc| 
        pmc.report.split(', ').include? month or pmc.report == 'Every month' or
        pmc.report.start_with? 'Next month'
      end
    end

    # source for shepherd information, yields a stream of director names
    # in random order
    class ShepherdStream < Enumerator
      def initialize
        @directors = ASF::Service['board'].members

        super do |generator|
          list = []
          loop do
            list = @directors.shuffle if list.empty?
            generator.yield list.pop.public_name
          end
        end
      end

      def for(pmc)
        chair = pmc.chair

        if @directors.include? chair
          "#{chair.public_name}"
        else
          "#{chair.public_name} / #{self.next.split(' ').first}"
        end
      end
    end
  end
end
