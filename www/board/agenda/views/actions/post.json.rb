#
# edit exiting / post new report
#
# Note: this code validates that env.user is one of the following:
#  1) an ASF member
#  2) a PMC chair
#  3) a member of the PMC for the report being posted
#

# special case for new special orders
if @attach == '7?'
  @message = "Post Special Order 7X: #{@title}"
elsif @attach == '8?'
  @message = "Post Discussion Item 8X: #{@title}"
end

attach = nil

# Determine if user is authorized
user = ASF::Person.find(env.user)
member_or_officer = (user.asf_member? or ASF.pmc_chairs.include? user)
real_web_server = env.password
alternate_credentials = (real_web_server and not member_or_officer) ?
  [['--username', 'whimsysvn']] : nil

# prepend user id to message if whimsysvn role account is used
@message = "#{env.user}: #{@message}" if env.user and alternate_credentials

Agenda.update(@agenda, @message, auth: alternate_credentials) do |agenda|
  # quick parse of agenda
  parsed = ASF::Board::Agenda.parse(agenda, true)

  # map @project to @attach to support posting from reporter.apache.org
  if not @attach and @project
    project = ASF::Committee.find(@project)
    raise "project #{@project.inspect} not found" unless project
    unless member_or_officer or project.owners.include? user
      raise "not authorized to post to #{@project}"
    end

    projectName = project.display_name
    parsed.each do |report|
      if report['title'] == projectName
        raise "report already posted" unless @digest or report['missing']
        attach = @attach = report[:attach]
        @digest ||= report['digest']
      end
    end
  elsif not ENV['RACK_ENV'] == 'test'
    raise "not authorized to post to the board agenda" unless member_or_officer
  end

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

    # update the commit message that will be used
    @message.sub! "7X", "7#{order}"

    # insert into agenda
    agenda[/\n() 8\. Discussion Items/, 1] = "#{title}#{@report}\n\n"

  elsif @attach == '8?'
    # new discussion item

    # adjust indentation
    indent = @report.scan(/^ +/).min
    @report.gsub!(/^#{indent}/, '') if indent
    @report.gsub!(/^(\S)/, '       \1')

    # add item letter to title
    discussion = agenda[/ 8\. Discussion Items.*\n 9\./m]
    items = discussion.scan(/^    ([A-Z]+)\./).flatten
    item = items.empty? ? 'A' : items.max.succ
    title = "    #{item}. #{@title}\n\n"

    # update the commit message that will be used
    @message.sub! "8X", "8#{item}"

    # insert into agenda
    agenda[/\n() 9\. .*Action Items/, 1] = "#{title}#{@report}\n\n"

  elsif @attach.start_with? '+'
    pmc_reports = parsed.select {|section| section[:attach] =~ /^[A-Z]/}
    attach = pmc_reports.last[:attach].succ
    pmc = ASF::Committee.find(@attach[1..-1])
    unless pmc.dn
      raise Exception.new("#{@attach[1..-1].inspect} PMC not found")
    end

    # select shepherd
    shepherds = pmc_reports.map {|section| section['shepherd']}.
      select {|shepherd| not shepherd.include? ' '}.
      group_by {|n| n}.map {|n, list| [n, list.length]}
    min = shepherds.map {|name, count| count}.min
    shepherd = shepherds.select {|name, count| count == min}.sample.first

    # insert section into committee-reports
    agenda[/\n() 7\. Special Orders/, 1] =
      "    #{attach}. Apache #{pmc.display_name} Project " +
      "[#{pmc.chair.public_name} / #{shepherd}]\n\n" +
      "       See Attachment #{attach}\n\n" +
      "       [ #{pmc.display_name}.\n" +
      "         approved:\n" +
      "         comments:\n" +
      "         ]\n\n"

    # insert report text as an attachment
    agenda[/^()-+\nEnd of agenda/, 1] =
      "-----------------------------------------\n" +
      "Attachment #{attach}: Report from the Apache #{pmc.display_name} " +
      "Project  [#{pmc.chair.public_name}]\n\n" +
      "#{@report.strip}\n\n"

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
    elsif @attach =~ /^[78]\w/
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

# filter agenda if project is specified or the user is not authorized to see
# the entire document
if @project or alternate_credentials
  agenda = _.delete 'agenda'
 _item agenda.find {|report| report[:attach] == attach}
end
