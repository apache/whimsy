# Front sections:
# * Call to Order
# * Roll Call

class ASF::Board::Agenda
  parse do
    scan @file, /
      ^\n\x20(?<section>[12]\.)
      \s(?<title>.*?)\n\n+
      (?<text>.*?)
      (?=\n\s[23]\.)
    /mx
  end
end
