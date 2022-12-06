#
# A two section representation of an agenda item (typically a PMC report),
# where the two sections will show up as two columns on wide enough windows.
#
# The first section contains the item text, with a missing indicator if
# the report isn't present.  It also contains an inline copy of draft
# minutes for agenda items in section 3.
#
# The second section contains posted comments, pending comments, and
# action items associated with this agenda item.
#
# Filters may be used to highlight or hypertext link portions of the text.
#

class Report < Vue
  def render
    _section.flexbox do
      _section do
        if @@item.warnings
          _ul.missing @@item.warnings do |warning|
            _li warning
          end
        end

        _pre.report do
          if @@item.text
            _Text raw: @@item.text, filters: filters
          elsif @@item.missing
            draft = Reporter.find(@@item)
            if draft
              _p do
                _em 'Unposted draft being prepared at '
                _a 'reporter.apache.org',
                  href: "https://reporter.apache.org/wizard?#{draft.project}"
                _span ':'
              end
              _Text raw: draft.text, filters: [self.draft]
            else
              _p {_em 'Missing'}
            end
          else
            _p {_em 'Empty'}
          end
        end

        if (@@item.missing or @@item.comments) and @@item.mail_list
          _section.reminder do
            if @@item.missing
              if not Posted.get(@@item.title).empty? or Reporter.find(@@item)
                _button.btn.btn_primary 'post report', data_toggle: 'modal',
                  data_target: '#post-report-form'
              elsif
                @@item.attach =~ /^[A-Z]/ and
                User.firstname and @@item.shepherd and
                User.firstname.start_with? @@item.shepherd.downcase()
              then
                _p.comment do
                  _ 'No report was found on '
                  _a 'board@apache.org',
                    href: 'https://lists.apache.org/list.html?board@apache.org'
                  _ ' archives since the last board report.  If/when a report'
                  _ ' is posted there with a '
                  _tt '[Report]'
                  _ ' tag in the subject line a POST button will appear here '
                  _ ' to assist with the posting the report.'
                end
              end
            end

            _Email item: @@item
          end
        end

        if minutes
          _pre.comment do
            if minutes === :missing
              _p { _em 'missing' }
            else
              _Text raw: minutes, filters: [hotlink]
            end
          end
        end
      end

      _section do
        _AdditionalInfo item: @@item

        _div.report_info do
          _h4 'Report Info'
          _Info item: @@item
        end
      end
    end
  end

  # determine what text filters to run
  def filters
    list = [self.linebreak, self.todo, hotlink, self.privates, self.jira,
      self.cve]
    list = [self.localtime, hotlink] if @@item.title == 'Call to order'
    list << self.names if @@item.people
    list << self.president_attachments if @@item.title == 'President'
    list << self.linkMinutes if @@item.attach =~ /^[37][A-Z]$/

    list
  end

  # special processing for Minutes from previous meetings
  def minutes
    if @@item.attach =~ /^3[A-Z]$/
      # if draft is available, fetch minutes for display
      date = @@item.text[/board_minutes_(\d+_\d+_\d+)\.txt/, 1]

      if date and not defined? @@item.minutes and defined? XMLHttpRequest
        if @@item.mtime
          Vue.set @@item, 'minutes', ''
          retrieve "minutes/#{date}?#{@@item.mtime}", :text do |minutes|
            @@item.minutes = minutes
          end
        else
          @@item.minutes = :missing
        end
      end
    end

    @@item.minutes
  end

  #
  ### filters
  #

  # Highlight todos
  def todo(text)
    return text.gsub 'TODO', '<span class="missing">TODO</span>'
  end

  # Break long lines, treating HTML Entities (like &amp;) as one character
  def linebreak(text)
    # find long, breakable lines
    regex = Regexp.new(/(\&\w+;|.){80}.+/, 'g')
    result = nil
    indices = [];
    while result = regex.exec(text)
      line = result[0]
      break if line.gsub(/\&\w+;/, '.').length < 80

      lastspace = /^.*\s\S/.exec(line)
      if lastspace and lastspace[0].gsub(/\&\w+;/, '.').length - 1 > 40
        indices.unshift([line, result.index])
      end
    end

    # reflow each line found
    indices.each do |info|
      line = info[0]
      index = info[1]
      replacement = '<span class="hilite" title="reflowed">' +
        Flow.text(line) + "</span>"

      text = text.slice(0, index) + replacement +
        text.slice(index + line.length)
    end

    return text
  end

  # Convert start time to local time on Call to order page
  def localtime(text)
    return text.sub /\n(\s+)(Other Time Zones:.*)/ do |match, spaces, text|
      localtime = Date.new(@@item.timestamp).toLocaleString()
      "\n#{spaces}<span class='hilite'>" +
        "Local Time: #{localtime}</span>#{spaces}#{text}"
    end
  end

  # replace ids with committer links
  def names(text)
    roster = '/roster/committer/'

    @@item.people.each_pair do |id, person|
      # email addresses in 'Establish' resolutions and (ids) everywhere
      text.gsub! /(\(|&lt;)(#{escapeRegExp(id)})( at |@|\))/ do |m, pre, id, post|
        if person.icla
          if post == ')' and person.member
            "#{pre}<b><a href='#{roster}#{id}'>#{id}</a></b>#{post}"
          else
            "#{pre}<a href='#{roster}#{id}'>#{id}</a>#{post}"
          end
        else
          "#{pre}<a class='missing' href='#{roster}?q=#{person.name}'>" +
            "#{id}</a>#{post}"
        end
      end

      # names
      if person.icla or @@item.title == 'Roll Call'
        pattern = escapeRegExp(person.name).gsub(/ +/, '\s+')
        if defined? person.member
          text.gsub! /#{pattern}/ do |match|
            "<a href='#{roster}#{id}'>#{match}</a>"
          end
        else
          text.gsub! /#{pattern}/ do |match|
            "<a href='#{roster}?q=#{person.name}'>#{match}</a>"
          end
        end
      end

      # highlight potentially misspelled names
      if person.icla and not person.icla == person.name
        names = person.name.split(/\s+/)
        iclas = person.icla.split(/\s+/)
        ok = false
        ok ||= names.all? {|part| iclas.any? {|icla| icla.include? part}}
        ok ||= iclas.all? {|part| names.any? {|name| name.include? part}}
        if @@item.title =~ /^Establish/ and not ok
          text.gsub! /#{escapeRegExp("#{id}'>#{escapeRegExp(person.name)}")}/,
            "?q=#{encodeURIComponent(person.name)}'>" +
            "<span class='commented'>#{person.name}</span>"
        else
          text.gsub! /#{escapeRegExp(person.name)}/,
            "<a href='#{roster}#{id}'>#{person.name}</a>"
        end
      end

      # put members names in bold
      if person.member
        pattern = escapeRegExp(person.name).gsub(/ +/, '\s+')
        text.gsub!(/#{pattern}/) {|match| "<b>#{match}</b>"}
      end
    end

    # treat any unmatched names in Roll Call as misspelled
    if @@item.title == 'Roll Call'
      text.gsub! /(\n\s{4})([A-Z].*)/ do |match, space, name|
        "#{space}<a class='commented' href='#{roster}?q=#{name}'>#{name}</a>"
      end
    end

    # highlight any non-apache.org email addresses in establish resolutions
    if @@item.title =~ /^Establish/
      text.gsub! /(&lt;|\()[-.\w]+@(([-\w]+\.)+\w+)(&gt;|\))/ do |match|
        if match =~ /@apache\.org/
          match
        else
          '<span class="commented" title="non @apache.org email address">' +
          match + '</span>'
        end
      end
    end


    # highlight mis-spelling of previous and proposed chair names
    if @@item.title.start_with? 'Change' and text =~ /\(\w[-_.\w]+\)/
      text.sub!(/heretofore\s+appointed\s+(\w(\s|.)*?)\s+\(/) do |text, name|
        text.sub(name, "<span class='hilite'>#{name}</span>")
      end

      text.sub!(/chosen\sto\s+recommend\s+(\w(\s|.)*?)\s+\(/) do |text, name|
        text.sub(name, "<span class='hilite'>#{name}</span>")
      end
    end

    return text
  end

  # link to board minutes and other attachments
  def linkMinutes(text)
    text.gsub! /board_minutes_(\d+)_\d+_\d+\.txt/ do |match, year|
      if Server.drafts.include? match
        link = "https://svn.apache.org/repos/private/foundation/board/#{match}"
      else
        link = "http://apache.org/foundation/records/minutes/#{year}/#{match}"
      end
      "<a href='#{link}'>#{match}</a>"
    end

    footer = ''

    text.gsub! /Attachment (\w+)/ do |match, attach|
      item = Agenda.index.find {|item| item.attach == attach}
      if item
        footer += "<hr/><h4>#{match}</h4><pre>#{item.text}</pre>"
        "<a href='#{item.title.gsub(' ', '-')}'>#{match}</a>"
      else
        match
      end
    end

    return text + footer
  end

  # highlight private sections - these sections appear in the agenda but
  # will be removed when the minutes are produced (see models/minutes.rb)
  def privates(text)
    # block of lines (and preceding whitespace) where the first line starts
    # with <private> and the last line ends </private>.
    private_lines =
      Regexp.new('^([ \t]*&lt;private&gt;(?:\n|.)*?&lt;/private&gt;)(\s*)$',
      'mig')

    # mark private sections with class private
    text.gsub!(private_lines) do |match, text|
      "<div class='private'>#{text}</div>"
    end

    # flag remaining private markers
    private_tag =/(\s*.\s*)(&lt;\/?private&gt;)(\s*.\s*)/i
    text.gsub! private_tag do |match, before, text, after|
      if before.include? '>' or after.include? '<'
        match
      elsif before.include? "\n" or after.include? "\n"
        match
      else
        "#{before}<span class='error' " +
        "title='private sections must consist only of full lines of text'" +
        ">#{text}</span>#{after}"
      end
    end

    return text
  end

  # expand president's attachments
  def president_attachments(text)
    match = text.match(/Additionally, please see Attachments (\d) through (\d)/)
    if match
      agenda = Agenda.index
      for i in 0...agenda.length
        next unless agenda[i].attach =~ /^\d$/
        if agenda[i].attach >= match[1] and agenda[i].attach <= match[2]
          text += "\n  #{agenda[i].attach}. " +
            "<a #{ agenda[i].text.empty? ? 'class="pres-missing" ' : ''}" +
            "href='#{agenda[i].href}'>#{agenda[i].title}</a>"
        end
      end
    end

    return text
  end

  # hotlink to JIRA issues
  def jira(text)
    jira_issue =
      Regexp.new(/(^|\s|\(|\[)([A-Z][A-Z0-9]+)-([1-9][0-9]*)
        (\.(\D|$)|[,;:\s)\]]|$)/x, 'g')

    text.gsub! jira_issue do |m, pre, name, issue, post|
      if JIRA.find(name)
        return "#{pre}<a target='_self' " +
          "href='https://issues.apache.org/jira/browse/#{name}-#{issue}'>" +
          "#{name}-#{issue}</a>#{post}"
      else
        return "#{pre}#{name}-#{issue}#{post}"
      end
    end

    return text
  end

  # hotlink to CVE
  def cve(text)
    return text.gsub(/\bCVE-\d{4}-\d{4,}\b/) do |id|
      "<a href='https://cve.mitre.org/cgi-bin/cvename.cgi?name=#{id}'>#{id}</a>"
    end
  end

  def draft(text)
    return "<div class='private'>#{text}</div>"
  end
end
