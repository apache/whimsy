# Minutes from previous meetings


class ASF::Board::Agenda
  # Must be outside scan loop.  Use find to placate Travis.
  FOUNDATION_BOARD = ASF::SVN.find('foundation_board')
  MINUTES = ASF::SVN.find('minutes')

  parse do
    minutes = @file.split(/^ 3. Minutes from previous meetings/,2).last.
      split(OFFICER_SEPARATOR,2).first

    pattern1 = /
      \s{4}(?<section>[A-Z])\.
      \sThe.meeting.of\s+(?<title>.*?)\n
      (?<text>.*?)
      \[\s(?:.*?):\s*?(?<approved>.*?)
      \s*comments:(?<comments>.*?)\n
      \s{8,9}\]\n
    /mx

    scan minutes, pattern1 do |attrs|
      attrs['section'] = '3' + attrs['section']
      attrs['text'] = attrs['text'].strip
      attrs['approved'] = attrs['approved'].strip.gsub(/\s+/, ' ')

      if FOUNDATION_BOARD
        file = attrs['text'][/board_minutes[_\d]+\.txt/]

        if file and File.exist?(File.join(FOUNDATION_BOARD, file))
          # unpublished minutes
          attrs['mtime'] = File.mtime(File.join(FOUNDATION_BOARD, file)).to_i
        else
          year = file[/_(\d{4})_/, 1]
          if MINUTES and File.exist? File.join(MINUTES, year, file)
            # published minutes
            attrs['mtime'] = File.mtime(File.join(MINUTES, year, file)).to_i
          end
        end
      end
    end

   pattern2 = /
     \s{4}(?<section>[A-Z])\.
     \s+(?<title>Action.*?)\n
     (?<text>.*)
   /mx

    scan minutes, pattern2 do |attrs|
      attrs['section'] = '3' + attrs['section']
      attrs['text'] = attrs['text'].strip
    end

  end
end
