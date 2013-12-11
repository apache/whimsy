# Attachments

class ASF::Board::Agenda
  parse do
    pattern = /
      -{41}\n
      Attachment\s\s?(?<attach>\w+):\s(?<title>.*?)\n+
      (?<report>.*?)\n
      (?=-{41,}\n(?:End|Attach))
    /mx

    scan @file, pattern do |attrs|
      attrs['title'].sub! /^Report from the VP of /, ''
      attrs['title'].sub! /^Report from the /, ''
      attrs['title'].sub! /^Status report for the /, ''
      attrs['title'].sub! /^Apache /, ''
      attrs['title'].sub! /\s*\[.*\]$/, ''
      attrs['title'].sub! /\sTeam$/, ''
      attrs['title'].sub! /\sCommittee$/, ''
      attrs['title'].sub! /\sProject$/, ''

      attrs['report'].sub! /\n+\Z/, "\n"
      attrs.delete('report') if attrs['report'] == "\n"
    end
  end
end
