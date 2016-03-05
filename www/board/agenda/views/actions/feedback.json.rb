#
# send feedback on reports
#

ASF::Mail.configure

# fetch minutes
@minutes = @agenda.sub('_agenda_', '_minutes_')
minutes_file = "#{AGENDA_WORK}/#{@minutes.sub('.txt', '.yml')}"
minutes_file.untaint if @minutes =~ /^board_minutes_\d+_\d+_\d+\.txt$/
date = @agenda[/\d+_\d+_\d+/].gsub('_', '-')

if File.exist? minutes_file
  minutes = YAML.load_file(minutes_file) || {}
else
  minutes = {}
end

# extract values for common fields
unless @from
  sender = ASF::Person.find(env.user || ENV['USER'])
  @from = "#{sender.public_name} <#{sender.id}@apache.org>".untaint
end

output = []

# iterate over the agenda
Agenda.parse(@agenda, :full).each do |item|
  # select exec officer, additional officer, and committee reports
  next unless item[:attach] =~ /^(4[A-Z]|\d|[A-Z]+)$/
  next unless item['chair_email']

  text = ''

  if item['comments'] and not item['comments'].empty?
    text += "\nComments:\n#{item['comments'].gsub(/^/, '  ')}\n"
  end

  if minutes[item['title']]
    text += "\nMinutes:\n#{minutes[item['title']].gsub(/^/, '  ')}\n"
  end

  next if text.strip.empty?

  # construct email
  mail = Mail.new do
    from @from
    to "#{item['owner']} <#{item['chair_email']}>".untaint
    subject "Board feedback on #{date} #{item['title']} report"

    if item['mail_list']
      if item[:attach] =~ /^[A-Z]+/
        cc "private@#{item['mail_list']}.apache.org".untaint
      else
        cc "#{item['mail_list']}@apache.org".untaint
      end
    end

    body text.strip.untaint
  end

  output << {
    attach: item[:attach],
    title: item['title'],
    mail: mail.to_s
  }
end

output
