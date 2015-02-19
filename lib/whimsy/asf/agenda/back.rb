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
      end

      if attrs['title'] =~ /Action Items/
        list = {}

        # extract action items associated with projects
        attrs['text'].to_s.split(/^\s+\* /).each do |action|
          next unless action =~ /\[ (\S*) \]\s*Status:/
          pmc = $1
          indent = action.scan(/\n +/).min
          action.gsub! indent, "\n" if indent
          action[/(\[ #{pmc} \])\s*Status:/, 1] = ''
          action.chomp!
          action.sub! /\s+Status:\Z/, ''
          list[pmc] ||= []
          list[pmc] << action
        end

        attrs['actions'] = list
      end
    end
  end
end
