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
      attrs['title'].sub! /^Review Outstanding /, ''
    end
  end
end
