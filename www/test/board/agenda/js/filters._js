#!/usr/bin/ruby

# define filters used in views to help with formatting

module Angular::AsfBoardFilters

  # determine the color of banners for a given agenda item
  filter :color do |item|
    if not item.title
      return 'blank'
    elsif item.text or item.report
      if item.approved and item.approved.length >= 5
        if item.comments
          return "commented"
        else
          return "reviewed"
        end
      else
        return "ready"
      end
    elsif item.text === undefined
      return "missing"
    else
      return "reviewed"
    end
  end

  # define regular expressions and constants used in converting an item
  # to HTML

  uri_in_text = Regexp.new(/(^|[\s.:;?\-\]<\(])
    (https?:\/\/[-\w;\/?:@&=+$.!~*'()%,#]+[\w\/])
    (?=$|[\s.:,?\-\[\]&\)])/x, "g")

  escape_html = Regexp.new('[&<>]', 'g')
  escape_replacement = {'&' => '&amp;', '<' => '&lt;', '>' => '&gt;'}

  private_sections =
    Regexp.new('^(\s*)(&lt;private&gt;(?:\n|.)*?&lt;/private&gt;)(\s*)$', 'mig')

  committer = 'https://whimsy.apache.org/roster/committer'

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
    text = text.gsub(private_sections, '$1<div class="private">$2</div>')

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
        text = text.gsub(/(\(|&lt;)(#{id})( at |@|\))/) do |m, pre, id, post|
          return "#{pre}<a href='#{committer}/#{id}'>#{id}</a>#{post}"
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
            "<a href='#/#{agenda[i].title}'>#{agenda[i].title}</a>"
        end
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
end
