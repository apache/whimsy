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

      # join multiline titles
      while attrs['report'].start_with? '        '
        append, attrs['report'] = attrs['report'].split("\n", 2)
        attrs['title'] += ' ' + append.strip
      end

      attrs['title'].sub! %r{^Report from the VP of }, ''
      attrs['title'].sub! %r{^Report from the }, ''
      attrs['title'].sub! %r{^Status report for the }, ''
      attrs['title'].sub! %r{^Apache }, ''
      attrs['title'].sub! 'Apache Software Foundation', 'ASF'

      if attrs['title'] =~ /\s*\[.*\]$/
        attrs['owner'] = attrs['title'][/\[(.*?)\]/, 1]
        attrs['title'].sub! %r{\s*\[.*\]$}, ''
      end

      attrs['title'].sub! %r{\sTeam$}, ''
      attrs['title'].sub! %r{\sCommittee$}, ''
      attrs['title'].sub! %r{\sProject$}, ''

      attrs['digest'] = Digest::MD5.hexdigest(attrs['report'].strip)

      attrs['report'].sub! %r{\n+\Z}, "\n"
      attrs.delete('report') if attrs['report'] == "\n"

      attrs['missing'] = true if attrs['report'].strip.empty?

      unless @quick
        begin
          committee = ASF::Committee.find(attrs['title'])
          attrs['chair_email'] = "#{committee.chair.id}@apache.org"
          attrs['mail_list'] = committee.mail_list
          attrs.delete('mail_list') if attrs['mail_list'].include? ' '

          attrs['notes'] = $1 if committee.report =~ /^Next month: (.*)/
        rescue
        end
      end

      if attrs['report'].to_s.include? "\uFFFD"
        attrs['warnings'] = ['UTF-8 encoding error']
      end
    end
  end
end
