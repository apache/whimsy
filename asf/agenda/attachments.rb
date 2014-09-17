# Attachments

class ASF::Board::Agenda
  parse do
    pattern = /
      -{41}\n
      Attachment\s\s?(?<attach>\w+):\s(?<title>.*?)\n+
      (?<report>.*?)
      (?=-{41,}\n(?:End|Attach))
    /mx

    scan @file, pattern do |attrs|

      attrs['title'].sub! /^Report from the VP of /, ''
      attrs['title'].sub! /^Report from the /, ''
      attrs['title'].sub! /^Status report for the /, ''
      attrs['title'].sub! /^Apache /, ''

      if attrs['title'] =~ /\s*\[.*\]$/
        attrs['owner'] = attrs['title'][/\[(.*?)\]/, 1]
        attrs['title'].sub! /\s*\[.*\]$/, ''
      end

      attrs['title'].sub! /\sTeam$/, ''
      attrs['title'].sub! /\sCommittee$/, ''
      attrs['title'].sub! /\sProject$/, ''

      attrs['digest'] = Digest::MD5.hexdigest(attrs['report'])

      attrs['report'].sub! /\n+\Z/, "\n"
      attrs.delete('report') if attrs['report'] == "\n"

      attrs['missing'] = true if attrs['report'].strip.empty?

      begin
        attrs['chair_email'] = ASF::Committee.find(attrs['title']).chair.mail
      rescue
      end
    end
  end
end
