#
# Discussion Items
#

class ASF::Board::Agenda
  parse do
    discussion = @file.split(/^ \d. Discussion Items\n/, 2).last.
      split(/^ \d. .*Action Items/, 2).first

    if discussion !~ /\A\s{3,5}[0-9A-Z]\.\s/

      # One (possibly empty) item for all Discussion Items

      pattern = /
        ^(?<attach>\s8\.)
        \s(?<title>.*?)\n
        (?<text>.*?)
        (?=\n[\s1]\d\.|\n===)
      /mx

      scan @file, pattern do |attrs|
        attrs['attach'].strip!
        attrs['prior_reports'] = minutes(attrs['title'])
      end

    else

      # Separate items for each individual Discussion Item

      pattern = /
        \n+(?<indent>\s{3,5})(?<section>[0-9A-Z])\.
        \s(?<title>.*?)\n
        (?<text>.*?)
        (?=\n\s{3,5}[0-9A-Z]\.\s|\z)
      /mx

      scan discussion, pattern do |attrs|
        attrs['section'] = '8' + attrs['section']
        attrs['warnings'] = ['Body is missing'] if attrs['text'].strip.empty?
      end
    end
  end
end
