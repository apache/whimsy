# Special Orders

class ASF::Board::Agenda
  parse do
    orders = @file.split(/^ 7. Special Orders/,2).last.
      split(/^ 8. Discussion Items/,2).first

    pattern = /
      \s{4}(?<section>[A-Z])\.
      \s(?<title>.*?)\n
      (?<text>.*?)
      (?=\n\s{4}[A-Z]\.\s|\z)
    /mx

    scan orders, pattern do |attrs|
      attrs['section'] = '7' + attrs['section'] 

      title = attrs['title']
      title.sub! /^Resolution to /, ''
      title.sub! /\sthe\s/, ' '
      title.sub! /\sApache\s/, ' '
      title.sub! /\sCommittee\s/, ' '
      title.sub! /\sProject(\s|$)/, '\1'
      title.sub! /\sPMC(\s|$)/, '\1'
      title.sub! /\s\(.*\)$/, ''

      text = attrs['text']

      asfid = '[a-z][-a-z0-9_]+'
      list_item = '^\s*(?:[-*\u2022]\s*)?(.*?)\s+'

      people = text.scan(/#{list_item}\((#{asfid})\)\s*$/)
      people += text.scan(/#{list_item}<(#{asfid})(?:@|\s*at\s*)
        (?:\.\.\.|apache\.org)>\s*$/x)

      unless people.empty?
        if text =~ /FURTHER RESOLVED, that ([^,]*?),?\s+be\b/
          chairname = $1.gsub(/\s+/, ' ').strip
          chair = people.find {|person| person.first == chairname}
          attrs['chair'] = {(chair ? chair.last : '') => {name: chairname}}
        end

        people.map! do |person| 
          [person.last, {name: person.first}]
        end

        attrs['people'] = Hash[people]
      end
    end
  end
end
