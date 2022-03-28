# Additional Officer Reports and Committee Reports

class ASF::Board::Agenda
  parse do
    pattern = /
      \[(?<owner>[^\n]+)\]\n\n
      \s{7}See\sAttachment\s\s?(?<attach>\w+)[^\n]*?\s+
      \[\s[^\n]*\s*approved:\s*?(?<approved>.*?)
      \s*comments:(?<comments>.*?)\n\s{9}\]
    /mx

    scan @file, pattern do |attrs|
      attrs['shepherd'] = attrs['owner'].split('/').last.strip
      attrs['owner'] = attrs['owner'].split('/').first.strip

      attrs['comments'].gsub! %r{^ {1,10}(\w+:)}, '\1'
      attrs['comments'].gsub! %r{^ {11}}, ''
    end
  end
end
