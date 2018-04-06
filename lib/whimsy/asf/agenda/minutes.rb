# Minutes from previous meetings

class ASF::Board::Agenda
  parse do
    minutes = @file.split(/^ 3. Minutes from previous meetings/,2).last.
      split(OFFICER_SEPARATOR,2).first

    pattern = /
      \s{4}(?<section>[A-Z])\.
      \sThe.meeting.of\s+(?<title>.*?)\n
      (?<text>.*?)
      \[\s(?:.*?):\s*?(?<approved>.*?)
      \s*comments:(?<comments>.*?)\n
      \s{8,9}\]\n
    /mx

    scan minutes, pattern do |attrs|
      attrs['section'] = '3' + attrs['section'] 
      attrs['text'] = attrs['text'].strip
      attrs['approved'] = attrs['approved'].strip.gsub(/\s+/, ' ')
    end
  end
end
