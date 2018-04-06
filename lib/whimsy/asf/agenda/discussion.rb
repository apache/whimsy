# 
# Discussion Items
#

class ASF::Board::Agenda
  parse do
    discussion = @file.split(/^ \d. Discussion Items\n/,2).last.
      split(/^ \d. .*Action Items/,2).first
    
    if discussion !~ /\A\s{3,5}[A-Z]\.\s/

      # One (possibly empty) item for all Discussion Items

      pattern = /
        ^(?<attach>\s[8]\.)
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
        \n+(?<indent>\s{3,5})(?<section>[A-Z])\.
        \s(?<title>.*?)\n
        (?<text>.*?)
        (?=\n\s{4}[A-Z]\.\s|\z)
      /mx

      scan discussion, pattern do |attrs|
        attrs['section'] = '8' + attrs['section'] 
      end
    end
  end
end
