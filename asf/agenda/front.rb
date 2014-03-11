# Front sections:
# * Call to Order
# * Roll Call

class ASF::Board::Agenda
  parse do
    pattern = /
      ^\n\x20(?<section>[12]\.)
      \s(?<title>.*?)\n\n+
      (?<text>.*?)
      (?=\n\s[23]\.)
    /mx

    scan @file, pattern do |attr|
      if attr['title'] == 'Roll Call'
        # attempt to identify the people mentioned
        ASF::Person.preload('cn')
        list = ASF::Person.list
        attr['people'] = {}
        people = attr['text'].scan(/ {8}(\w.*)/).flatten.each do |sname|
          name = sname
          sname = sname.strip.downcase.split(/\s+/)
          list.select do |person|
            next if person == 'none'
            pname = person.public_name.downcase.split(/\s+/)
            if sname.all? {|t1| pname.any? {|t2| t2.start_with? t1}}
              attr['people'][person.id] = {
                name: name,
                member: person.asf_member?
              }
            end
          end
        end
      end
    end
  end
end
