# Special Orders

class ASF::Board::Agenda
  parse do
    orders = @file.split(/^ \d. Special Orders/,2).last.
      split(/^ \d. Discussion Items/,2).first

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
      title.strip!
      fulltitle = title.dup
      title.sub! /^Resolution to /, ''
      title.sub! /\sthe\s/, ' '
      title.sub! /\sApache\s/, ' '
      title.sub! /\sCommittee\s/, ' '
      title.sub! /\sProject(\s|$)/i, '\1'
      title.sub! /\sPMC(\s|$)/, '\1'

      if title =~ /^Establish .* \((.*)\)$/
        title.sub! /\s.*?\(/, ' '
        title.sub! /\)$/, ''
      else
        title.sub! /\s\(.*\)$/, ''
      end

      attrs['fulltitle'] = fulltitle if title != fulltitle

      text = attrs['text']
      attrs['digest'] = Digest::MD5.hexdigest(attrs['text'])

      attrs['warnings'] = []
      if attrs['indent'] != '    '
        attrs['warnings'] << 'Heading is not indented 4 spaces'
      end
      if text.sub(/s+\Z/,'').scan(/^ *\S/).map(&:length).min != 8
        attrs['warnings'] << 'Resolution is not indented 7 spaces'
      end

      title_checks = {
        /^Establish/i => /^Establish the Apache .* Project$/,
        /^Change.*Chair/i => /^Change the Apache .* Project Chair$/,
        /^Terminate/i => /^Terminate the Apache .* Project$/,
      }

      title_checks.each do |select, match|
        if fulltitle =~ select and fulltitle !~ match and
          fulltitle !~ /Establish.*position/i
       then
          attrs['warnings'] << 
            "Non-standard title wording: #{fulltitle.inspect}; " +
            "expected #{match.inspect}"
        end
      end

      attrs.delete 'indent'
      attrs.delete 'warnings' if attrs['warnings'].empty?

      next if @quick

      asfid = '[a-z][-.a-z0-9_]+' # dot added to help detect errors
      list_item = '^[[:blank:]]*(?:[-*\u2022]\s*)?(.*?)[[:blank:]]+'

      people = text.scan(/#{list_item}\((#{asfid})\)\s*$/)
      people += text.scan(/#{list_item}\((#{asfid})(?:@|\s*at\s*)
        (?:\.\.\.|apache\.org|apache\sdot\sorg)\)\s*$/xi)
      people += text.scan(/#{list_item}<(#{asfid})(?:@|\s*at\s*)
        (?:\.\.\.|apache\.org|apache\sdot\sorg)>\s*$/xi)

      need_chair = false

      whimsy = 'https://whimsy.apache.org'
      if title =~ /Change (.*?) Chair/ or title =~ /Terminate (\w+)$/
        people.clear
        committee = ASF::Committee.find($1)
        attrs['roster'] =
          "#{whimsy}/roster/committee/#{CGI.escape committee.name}"
        attrs['stats'] = 
          "https://reporter.apache.org/?#{CGI.escape committee.name}"
        attrs['prior_reports'] = minutes(committee.display_name)

        ids = text.scan(/\((\w[-.\w]+)\)/).flatten
        unless ids.empty?
          ids.each do |id|
            person = ASF::Person.find(id)
            people << [person.public_name, id] if person.icla
          end
        end

        next unless committee.names
        committee.names.each do |id, name|
          people << [name, id] if text.include? name
        end

        if people.length < 2 and not title.start_with? 'Terminate'
          attrs['warnings'] ||= ['Unable to match expected number of names']
          attrs['names'] = committee.names
        end

        need_chair = true if title =~ /Change (.*?) Chair/

      elsif title =~ /Establish (.*)/
        name = $1
        attrs['prior_reports'] =
          "#{whimsy}/board/minutes/#{name.gsub(/\W/,'_')}"

        if text.scan(/[<(][-.\w]+@(?:[-\w]+\.)+\w+[>)]/).
          any? {|email| not email.include? 'apache.org'}
        then
          attrs['warnings'] ||= ['non apache.org email address found'] 
        end

        need_chair = true unless fulltitle =~ /Establish.*position/i
      end

      if need_chair
        if text =~ /FURTHER RESOLVED, that\s+([^,]*?),?\s+be\b/
          chairname = $1.gsub(/\s+/, ' ').strip

          if chairname =~ /\s\(([-.\w]+)\)$/
            # if chair's id is present in parens, use that value
            attrs['chair'] = $1 unless $1.empty?
            chairname.sub! /\s+\(.*\)$/, ''
          else
            # match chair's name against people in the committee
            chair = people.find {|person| person.first == chairname}
            attrs['chair'] = (chair ? chair.last : nil)
          end

          unless people.include? [chairname, attrs['chair']]
            if people.empty?
              attrs['warnings'] ||= ['Unable to locate PMC email addresses'] 
            elsif attrs['chair']
              attrs['warnings'] ||= ['Chair not member of PMC'] 
            else
              attrs['warnings'] ||= ['Chair not found in resolution'] 
            end
          end
        else
          attrs['warnings'] ||= ['Chair not found in resolution'] 
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
