#
# send feedback on reports
#

ASF::Mail.configure

validate_board_file(@agenda)

# fetch minutes
@minutes = @agenda.sub('_agenda_', '_minutes_')
minutes_file = File.join(AGENDA_WORK, @minutes.sub('.txt', '.yml'))
date = @agenda[/\d+_\d+_\d+/].gsub('_', '-')

if File.exist? minutes_file
  minutes = YAML.load_file(minutes_file) || {}
else
  minutes = {}
end

feedback_sent = minutes[:todos][:feedback_sent] rescue []

# extract values for common fields
if @from
  from = @from
else
  sender = ASF::Person.find(env.user || ENV['USER'])
  from = "#{sender.public_name.inspect} <#{sender.id}@apache.org>"
end

output = []

# iterate over the agenda
Agenda.parse(@agenda, :full).each do |item|
  # select exec officer, additional officer, and committee reports
  next unless item[:attach] =~ /^(4[A-Z]|\d|[A-Z]+)$/
  next unless item['chair_email']
  next unless @dryrun or @checked[item['title'].gsub(/\s/, '_')]

  # collect comments and minutes
  text = ''

  if item['comments'] and not item['comments'].empty?
    comments = item['comments'].gsub(/^(\S)/, "\n\\1")
    text += "\nComments:\n#{comments.gsub(/^/, '  ')}\n"
  end

  if minutes[item['title']]
    text += "\nMinutes:\n\n#{minutes[item['title']].gsub(/^/, '  ')}\n"
  end

  next if text.strip.empty?

  # add standard footer
  text += "\n" + %{
    This feedback was generated automatically by the secretary from the
    comments made on your board report.
    Comments that do not ask specific questions should be noted by the PMC
    and taken into consideration as appropriate for future board reports.
    Where a comment asks a specific question, it should be answered in your
    next board report unless otherwise stated in the comment.
    If you have any queries or concerns regarding any of the comments they
    should be sent to the board@ mailing list.
  }.gsub(/^ {4}/, '').strip

  # build cc list
  cc = []
  # we don't want replies to come to secretary@
  bcc = ['secretary@apache.org']

  if item['mail_list']
    if item[:attach] =~ /^[A-Z]+/
      cc << "private@#{item['mail_list']}.apache.org"
    elsif item['mail_list'].include? '@'
      cc << item['mail_list']
    else
      cc << "#{item['mail_list']}@apache.org"
    end
  end

  # construct email
  mail = Mail.new do
    from from
    to "#{item['owner']} <#{item['chair_email']}>"
    cc cc
    bcc bcc
    reply_to ['board@apache.org'] + cc
    subject "Board feedback on #{date} #{item['title']} report"

    body text.strip
  end

  mail.deliver! unless @dryrun

  # add to output
  output << {
    attach: item[:attach],
    title: item['title'],
    sent: (not @dryrun),
    mail: mail.to_s
  }
end

# indicate that feedback has been sent
unless @dryrun
  minutes[:todos] ||= {}
  minutes[:todos][:feedback_sent] ||= []
  minutes[:todos][:feedback_sent] += output.map {|item| item[:title]}
  File.write minutes_file, YAML.dump(minutes)
end

# return output to client
output
