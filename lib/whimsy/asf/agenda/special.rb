# Special Orders

class ASF::Board::Agenda
  parse do
    orders = @file.split(/^ 7. Special Orders/,2).last.
      split(/^ 8. Discussion Items/,2).first

    pattern = /
      \n+(?<indent>\s{3,5})(?<section>[A-Z])\.
      \s(?<title>.*?)\n
      (?<text>.*?)
      (?=\n\s{4}[A-Z]\.\s|\z)
    /mx

    people = []
    scan orders, pattern do |attrs|
      attrs['section'] = '7' + attrs['section'] 

      title = attrs['title']
      fulltitle = title.dup
      title.sub! /^Resolution to /, ''
      title.sub! /\sthe\s/, ' '
      title.sub! /\sApache\s/, ' '
      title.sub! /\sCommittee\s/, ' '
      title.sub! /\sProject(\s|$)/, '\1'
      title.sub! /\sPMC(\s|$)/, '\1'
      title.sub! /\s\(.*\)$/, ''

      attrs['fulltitle'] = fulltitle if title != fulltitle

      text = attrs['text']
      attrs['digest'] = Digest::MD5.hexdigest(attrs['text'])

      attrs['warnings'] = []
      if attrs['indent'] != '    '
        attrs['warnings'] << 'Heading is not indented 4 spaces'
        attrs['warnings'] << attrs['indent'].inspect
        attrs['warnings'] << attrs['indent'].length
      end
      if text.sub(/s+\Z/,'').scan(/^ *\S/).map(&:length).min != 8
        attrs['warnings'] << 'Resolution is not indented 7 spaces'
      end
      attrs.delete 'indent'
      attrs.delete 'warnings' if attrs['warnings'].empty?

      next if @quick

      asfid = '[a-z][-.a-z0-9_]+' # dot added to help detect errors
      list_item = '^\s*(?:[-*\u2022]\s*)?(.*?)\s+'

      people = text.scan(/#{list_item}\((#{asfid})\)\s*$/)
      people += text.scan(/#{list_item}\((#{asfid})(?:@|\s*at\s*)
        (?:\.\.\.|apache\.org)\)\s*$/x)
      people += text.scan(/#{list_item}<(#{asfid})(?:@|\s*at\s*)
        (?:\.\.\.|apache\.org|apache\sdot\sorg)>\s*$/x)

      whimsy = 'https://whimsy.apache.org'
      if people.empty?
        if title =~ /Change (.*?) Chair/ or title =~ /Terminate (\w+)$/
          committee = ASF::Committee.find($1)
          attrs['roster'] =
            "#{whimsy}/roster/committee/#{CGI.escape committee.name}"
          attrs['prior_reports'] = minutes(committee.display_name)
          name1 = text[/heretofore\sappointed\s(\w.*)\sto/,1]
          sname1 = name1.to_s.downcase.gsub('.', ' ').split(/\s+/)
          name2 = text[/recommend\s(\w.*)\sas/,1]
          sname2 = name2.to_s.downcase.gsub('.', ' ').split(/\s+/)
          next unless committee.names
          committee.names.each do |id, name|
            name.sub!(/ .* /,' ') unless text.include? name
            pname = name.downcase.split(/\s+/)
            if text.include? name
              people << [name, id]
            elsif name1 && sname1.all? {|t1| pname.any? {|t2| t2.start_with? t1}}
              people << [name1, id]
            elsif name1 && pname.all? {|t1| sname1.any? {|t2| t2.start_with? t1}}
              people << [name1, id]
            elsif name2 && sname2.all? {|t1| pname.any? {|t2| t2.start_with? t1}}
              people << [name2, id]
            elsif name2 && pname.all? {|t1| sname2.any? {|t2| t2.start_with? t1}}
              people << [name2, id]
            end
          end
        end
      else
        if title =~ /Establish (.*)/
          name = $1
          attrs['prior_reports'] =
            "#{whimsy}/board/minutes/#{name.gsub(/\W/,'_')}"
          if text =~ /FURTHER RESOLVED, that ([^,]*?),?\s+be\b/
            chairname = $1.gsub(/\s+/, ' ').strip
            chair = people.find {|person| person.first == chairname}
            attrs['chair'] = (chair ? chair.last : nil)
          end
        end

      end

      people.map! do |name, id| 
        person = ASF::Person.new(id)
        icla = person.icla
        [id, {name: name, icla: icla ? person.icla.name : false,
          member: person.asf_member?}]
      end

      attrs['people'] = Hash[people] unless people.empty?
    end
  end
end
