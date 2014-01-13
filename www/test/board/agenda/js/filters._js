#!/usr/bin/ruby

# define filters used in views to help with formatting

module Angular::AsfBoardFilters

  # determine the color of banners for a given agenda item
  filter :color do |item|
    if not item.title
      return 'blank'
    elsif item.text or item.report
      if item.approved
        if item.approved.length < 5
          return "ready"
        elsif item.comments
          return "commented"
        else
          return "reviewed"
        end
      elsif item.title == 'President' and item.report[0..12] == 'Additionally,'
        return "missing"
      else
        return "available"
      end
    elsif item.text === undefined
      return "missing"
    else
      return "reviewed"
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

  committer = 'https://whimsy.apache.org/roster/committer'

  jira_issue =
    Regexp.new(/(^|\s|\()([A-Z][A-Z0-9]+)-([1-9][0-9]*)([.,;]?($|\s|\)))/,
    'g')

  # convert an agenda item into HTML
  filter :html do |item|
    text = item.text || item.report

    # start by escaping everything
    if text and text != ''
      text = text.gsub(escape_html) {|c| return escape_replacement[c]}
    elsif item.text === undefined
      text = '<em>Missing</em>'
    else
      text = '<em>Empty</em>'
    end

    # highlight private sections
    text = text.gsub(private_sections, '<div class="private">$1$2</div>')

    # link to board minutes
    text = text.gsub(/(board_minutes_\d+_\d+_\d+)/, 
      '<a href="https://svn.apache.org/repos/private/foundation/board/$1.txt">$1</a>')

    # convert textual links into hyperlinks
    text = text.gsub(uri_in_text) do |match, pre, link|
      return "#{pre}<a href='#{link}'>#{link}</a>"
    end

    # replace ids with committer links
    if item.people
      for id in item.people
        person = item.people[id]

        text = text.gsub(/(\(|&lt;)(#{id})( at |@|\))/) do |m, pre, id, post|
          return "#{pre}<a href='#{committer}/#{id}'>#{id}</a>#{post}"
        end

        if person.member
          text = text.gsub(/#{escapeRegExp(person.name)}/) do 
            return "<b>#{person.name}</b>"
          end
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

    # link to JIRA issues
    text = text.gsub(jira_issue) do |m, pre, jira, issue, post|
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

  filter :approved do |agenda, pending|
    approved = []
    agenda.forEach do |item|
      approved.push item if pending.approved.include? item.attach
    end
    return approved
  end

  filter :comments do |agenda, pending|
    comments = []
    agenda.forEach do |item|
      if pending.comments[item.attach]
        item.comment = pending.comments[item.attach]
        comments.push(item)
      end
    end
    return comments
  end

  filter :show do |item, args|
    return false unless item.comments
    return true if args.toggle
    return args.seen[item.attach] != item.comments
  end
end
