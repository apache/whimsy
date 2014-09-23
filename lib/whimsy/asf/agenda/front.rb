# Front sections:
# * Call to Order
# * Roll Call

class ASF::Board::Agenda
  @@people_cache = {}

  parse do
    pattern = /
      ^\n\x20(?<section>[12]\.)
      \s(?<title>.*?)\n\n+
      (?<text>.*?)
      (?=\n\s[23]\.)
    /mx

    scan @file, pattern do |attr|
      if attr['title'] == 'Roll Call'
        attr['people'] = {}
        list = nil

        absent = attr['text'].scan(/Absent:\n\n.*?\n\n/m).join

        # attempt to identify the people mentioned in the Roll Call
        people = attr['text'].scan(/ {8}(\w.*)/).flatten.each do |sname|
          name = sname

          # first try the cache
          person = @@people_cache[name]

          # next try a simple name look up
          if not person
            search = ASF::Person.list("cn=#{name}")
            person = search.first if search.length == 1
          end

          # finally try harder to match the name
          if not person
            sname = sname.strip.downcase.split(/\s+/)

            if not list
              ASF::Person.preload('cn')
              list = ASF::Person.list
            end

            search = []
            list.select do |person|
              next if person == 'none'
              pname = person.public_name.downcase.split(/\s+/)
              if sname.all? {|t1| pname.any? {|t2| t2.start_with? t1}}
                search << person
              elsif pname.all? {|t1| sname.any? {|t2| t2.start_with? t1}}
                search << person
              end
            end

            person = search.first if search.length == 1
          end

          # save results in both the cache and the attributes
          if person
            @@people_cache[name] = person

            attr['people'][person.id] = {
              name: name,
              member: person.asf_member?,
              attending: !absent.include?(name)
            }
          end
        end
      elsif attr['title'] == 'Call to order'
        attr['timestamp'] = timestamp(attr['text'][/\d+:\d+([ap]m)?/])
      end
    end
  end
end
