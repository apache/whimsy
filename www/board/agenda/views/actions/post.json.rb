#
# edit exiting / post new report
#

# special case for new special orders
if @attach == '7?'
  @message = "Post Special Order 7X: #{@title}"
end

Agenda.update(@agenda, @message) do |agenda|

  # quick parse of agenda
  parsed = ASF::Board::Agenda.parse(agenda, true)

  # remove trailing whitespace
  @report.sub! /\s*\Z/, ''

  # convert unicode blank characters to an ASCII space
  @report.gsub!(/[[:blank:]]/, ' ')

  if @attach == '7?'
    # new special order

    # adjust indentation
    indent = @report.scan(/^ +/).min
    @report.gsub!(/^#{indent}/, '') if indent
    @report.gsub!(/^(\S)/, '       \1')

    # add order letter to title
    order = 'A'
    parsed.map {|section| section[:attach]}.
      select {|attach| attach =~ /^7\w/}.length.times {order.succ!}
    title = "    #{order}. #{@title}\n\n"

    # insert into agenda
    agenda[/\n() 8\. Discussion Items/, 1] = "#{title}#{@report}\n\n"

    # update the commit message that will be used
    @message.sub! "7X", "7#{order}"
  else
    item = parsed.find {|item| item[:attach]==@attach}

    if not item
      raise Exception.new("Attachment #{@attach.inspect} not found")
    elsif @digest != item['digest']
      raise Exception.new("Merge conflict")
    end

    spacing = "\n\n"

    if @attach =~ /^4\w/
      pattern = /(\n\n    #{@attach[-1]}\. #{item['title']} \[.*?\]).*?\n\n(    [B-Z]\.| 5\.)/m
      @report.gsub! /^(.)/, '       \1'
    elsif @attach =~ /^7\w/
      title = item['fulltitle'] || item['title']
      pattern = /(^\s+#{@attach[-1]}\.\s+#{title})\n.*?\n( {1,6}\w\.)/m
      @report.gsub! /^(.)/, '       \1'
    elsif @attach == '8.'
      title = 'Discussion Items'
      pattern = /^(\s8\. #{title})\n.*\n( 9\.)/m
      @report.gsub! /^(.)/, '    \1'
    else
      pattern = /(---\nAttachment #{@attach}:.*?\[.*?\])\n.*?\n(-{40})/m
      spacing = "\n\n\n"
    end

    spacing = "" if @report.empty?

    # President report has a custom footer - retain it
    if item['title'] == 'President' and agenda[pattern]
      footer = agenda[pattern][/\n\n(\s+Additionally.*?)\s+\w\.\Z/m, 1]
      @report += "\n\n#{footer}" if footer
    end

    if not agenda.sub!(pattern) { "#{$1}\n\n#{@report}#{spacing}#{$2}" }
      raise Exception.new('report merge failed')
    end
  end

  # return updated agenda
  agenda
end
