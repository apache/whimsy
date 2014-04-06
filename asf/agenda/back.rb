# Back sections:
# * Discussion Items
# * Review Outstanding Action Items
# * Unfinished Business
# * New Business
# * Announcements
# * Adjournment

class ASF::Board::Agenda
  parse do
    pattern = /
      ^(?<attach>(?:\s[89]|\s9|1\d)\.)
      \s(?<title>.*?)\n
      (?<text>.*?)
      (?=\n[\s1]\d\.|\n===)
    /mx

    scan @file, pattern do |attrs|
      attrs['attach'].strip!
      attrs['title'].sub! /^Review Outstanding /, ''

      if attrs['title'] =~ /Discussion|Action|Business|Announcements/
        attrs['prior_reports'] = minutes(attrs['title'])
      elsif attrs['title'] == 'Adjournment'
        attrs['timestamp'] = timestamp(attrs['text'][/\d+:\d+([ap]m)?/])
          attrs['secretary'] = []
          date = Date.parse(@file[/\w+ \d+, \d+/]).strftime('%Y_%m_%d')
          link = "/board/draft-minutes/#{date}"

          svn = ASF::SVN['private/foundation/board']
          if File.exist? "#{svn}/board_minutes_#{date}.txt"
            attrs['secretary'] << {text: 'Show minutes', link: link}
            attrs['secretary'] << {text: 'Publish minutes',
              link: "/board/agenda/#{date}/calendar_summary"}
          else
            attrs['secretary'] << {text: 'Draft minutes', link: link}
          end
        end
    end
  end
end
