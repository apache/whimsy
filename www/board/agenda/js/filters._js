#!/usr/bin/ruby

# define filters used in views to help with formatting

module Angular::AsfBoardFilters

  # determine the color of banners for a given agenda item
  filter :color do |item|
    if not item.title
      return 'blank'
    elsif item.warnings
      return 'missing'
    elsif item.missing
      return 'missing'
    elsif Pending.rejected.include? item.attach
      return 'missing'
    elsif item.approved
      if item.approved.length < 5
        return 'ready'
      elsif item.comments
        return 'commented'
      else
        return 'reviewed'
      end
    elsif item.text or item.report
      return 'available'
    elsif item.text === undefined
      return 'missing'
    else
      return 'reviewed'
    end
  end

  # define regular expressions and constants used in converting an item
  # to HTML

  def escapeRegExp(string)
    # https://developer.mozilla.org/en/docs/Web/JavaScript/Guide/Regular_Expressions
    return string.gsub(/([.*+?^=!:${}()|\[\]\/\\])/, "\\$1");
  end 

  uri_in_text = Regexp.new(/(^|[\s.:;?\-\]<\(])
    (https?:\/\/[-\w;\/?:@&=+$.!~*'()%,#]+[\w\/])
    (?=$|[\s.:,?\-\[\]&\)])/x, "g")

  escape_html = Regexp.new('[&<>]', 'g')
  escape_replacement = {'&' => '&amp;', '<' => '&lt;', '>' => '&gt;'}

  private_sections =
    Regexp.new('^([ \t]*)(&lt;private&gt;(?:\n|.)*?&lt;/private&gt;)(\s*)$',
    'mig')

  jira_issue =
    Regexp.new(/(^|\s|\()([A-Z][A-Z0-9]+)-([1-9][0-9]*)([.,;:]?($|\s|\)))/,
    'g')

  # convert an agenda item into HTML
  filter :html do |item|
    text = (typeof(item) === "string" ? item : item.text || item.report)

    # start by escaping everything
    if text and text != ''
      text.gsub!(escape_html) {|c| escape_replacement[c]}
    elsif item.text === undefined
      if Agenda.get().length == 0
        text = '<em>Loading...</em>'
      else
        text = '<em>Missing</em>'
      end
    else
      text = '<em>Empty</em>'
    end

    # highlight private sections
    text.gsub! private_sections, '<div class="private">$1$2</div>'

    # link to board minutes
    text.gsub! /board_minutes_(\d+)_\d+_\d+\.txt/ do |match, year|
      if Data.drafts.include? match
        link = "https://svn.apache.org/repos/private/foundation/board/#{match}"
      else
        link = "http://apache.org/foundation/records/minutes/#{year}/#{match}"
      end
      "<a href='#{link}'>#{match}</a>"
    end

    # convert textual links into hyperlinks
    text.gsub! uri_in_text do |match, pre, link|
      text = link
      text.sub!(%r{http://www.timeanddate.com/worldclock/fixedtime.html\?iso=(\d{4})(\d\d)(\d\d)T(\d\d)(\d\d).*}, '$1-$2-$3T$4:$5Z')
      "#{pre}<a href='#{link}'>#{text}</a>"
    end

    # Show Call to Order time in local time
    if item.timestamp
      text.sub! /\n(\s+)(Other Time Zones:.*)/ do |match, spaces, text|
        localtime = Date.new(item.timestamp).toLocaleString()
        "\n#{spaces}<span class='hilite'>Local Time: #{localtime}</span>#{spaces}#{text}"
      end
    end

    roster = 'https://whimsy.apache.org/roster/committer/'

    # replace ids with committer links
    if item.people
      for id in item.people
        person = item.people[id]

        # email addresses in 'Establish' resolutions
        text.gsub! /(\(|&lt;)(#{id})( at |@|\))/ do |m, pre, id, post|
          if person.icla
            "#{pre}<a href='#{roster}#{id}'>#{id}</a>#{post}"
          else
            "#{pre}<a class='missing' href='#{roster}?q=#{person.name}'>" +
              "#{id}</a>#{post}"
          end
        end

        # names
        if person.icla or item.title == 'Roll Call'
          text.sub! /#{escapeRegExp(person.name)}/, 
            "<a href='#{roster}#{id}'>#{person.name}</a>"
        end

        # highlight potentially misspelled names
        if person.icla and not person.icla == person.name
          names = person.name.split(/\s+/)
          iclas = person.icla.split(/\s+/)
          ok = false
          ok ||= names.all? {|part| iclas.any? {|icla| icla.include? part}}
          ok ||= iclas.all? {|part| names.any? {|name| name.include? part}}
          if item.title =~ /^Establish/ and not ok
            text.gsub! /#{escapeRegExp("#{id}'>#{person.name}")}/,
              "?q=#{encodeURIComponent(person.name)}'>" +
              "<span class='commented'>#{person.name}</span>"
          else
            text.gsub! /#{escapeRegExp(person.name)}/, 
              "<a href='#{roster}#{id}'>#{person.name}</a>"
          end
        end

        # put members names in bold
        if person.member
          text.gsub! /#{escapeRegExp(person.name)}/, "<b>#{person.name}</b>"
        end
      end

      # treat any unmatched names in Roll Call as misspelled
      if item.title == 'Roll Call'
        text.gsub! /(\n\s{4})([A-Z].*)/ do |match, space, name|
          "#{space}<a class='commented' href='#{roster}?q=#{name}'>#{name}</a>"
        end
      end

      if item.title =~ /^Change/
        text.gsub! /heretofore\sappointed\s(\w.*)\sto/ do |match, name|
          match.gsub name, 
            "<a class='missing' href='#{roster}?q=#{name}'>#{name}</a>"
        end
        text.gsub! /recommend\s(\w.*)\sas/ do |match, name|
          match.gsub name, 
            "<a class='missing' href='#{roster}?q=#{name}'>#{name}</a>"
        end
      end
    end

    # expand president's attachments
    match = text.match(/Additionally, please see Attachments (\d) through (\d)/)
    if match
      agenda = Agenda.get()
      for i in 0...agenda.length
        next unless agenda[i].attach =~ /^\d$/
        if agenda[i].attach >= match[1] and agenda[i].attach <= match[2]
          text += "\n  #{agenda[i].attach}. " +
            "<a #{ agenda[i].report.empty? ? 'class="pres-missing" ' : ''}" +
            "href='#{agenda[i].href}'>#{agenda[i].title}</a>"
        end
      end
    end

    if item.title == 'Action Items'
      text.gsub! /Status:\s*?(\n\n|$)/, 
        "<span class='missing'>Status:</span>$1"
    end

    # link to JIRA issues
    text.gsub! jira_issue do |m, pre, jira, issue, post|
      if JIRA.exist jira
        return "#{pre}<a target='_self' " +
          "href='https://issues.apache.org/jira/browse/#{jira}-#{issue}'>" +
          "#{jira}-#{issue}</a>#{post}"
      else
        return "#{pre}#{jira}-#{issue}#{post}"
      end
    end

    # return the resulting HTML
    return $sce.trustAsHtml(text)
  end

  filter :hilight do |text, search|
    if text and text != ''
      text.gsub!(escape_html) {|c| escape_replacement[c]}
      
      search = search.text.gsub(escape_html) {|c| escape_replacement[c]}
      text.gsub! /#{search}/i do |match|
        "<span class='hilite'>#{match}</span>"
      end
    end

    return $sce.trustAsHtml(text)
  end

  filter :approved do |agenda, pending|
    approved = []
    agenda.each do |item|
      approved << item if pending.approved.include? item.attach
    end
    return approved
  end

  filter :comments do |agenda, pending|
    comments = []
    agenda.each do |item|
      if pending.comments[item.attach]
        item.comment = pending.comments[item.attach]
        comments.push(item)
      end
    end
    return comments
  end

  filter :csplit do |text|
    comments = []
    return comments if text === undefined

    comment = ''
    text.split("\n").each do |line|
      if line =~ /^\S/
        comments << comment unless comment.empty?
        comment = line
      else
        comment += "\n" + line
      end
    end

    comments << comment unless comment.empty?
    return comments
  end
end
