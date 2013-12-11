# Executive Officer Reports

class ASF::Board::Agenda
  parse do
    reports = @file.split(/^ 4. Executive Officer Reports/,2).last.
      split(/^ 5. Additional Officer Reports/,2).first

    pattern = /
      \s{4}(?<section>[A-Z])\.
      \s(?<title>[^\[]+?)
      \s\[(?<owner>[^\]]+?)\]
      (?<text>.*?)
      (?=\n\s{4}[A-Z]\.\s|\z)
    /mx

    scan reports, pattern do |attrs|
      attrs['section'] = '4' + attrs['section'] 
      attrs['shepherd'] = attrs['owner'].split('/').last
      attrs['owner'] = attrs['owner'].split('/').first

      attrs['text'].sub! /\A\s+\n/, ''

      attrs['text'].gsub! /\n\n\s+\[ comments:(.*)\]\s*$/m do
        attrs['comments'] = $1.strip
        "\n"
      end
    end
  end
end
