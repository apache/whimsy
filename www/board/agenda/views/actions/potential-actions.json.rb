#
# potential actions
#

# get posted action items from previous report
if ENV['RACK_ENV'] == 'test'
  base = "#{FOUNDATION_BOARD}/board_agenda_2015_01_21.txt"
else
  today = Date.today.strftime("#{FOUNDATION_BOARD}/board_agenda_%Y_%m_%d.txt")
  base = Dir["#{FOUNDATION_BOARD}/board_agenda_*.txt"].
   select {|file| file <= today}.sort.last
end

parsed = ASF::Board::Agenda.parse(IO.read(base), true)
actions = parsed.find {|item| item['title'] == 'Action Items'}['actions']

# scan draft minutes for new action items
pattern = /^(?:@|AI\s+)(\w+):?\s+([\s\S]*?)(?:\n\n|$)/m
minutes = File.basename(base).sub('agenda', 'minutes').sub('.txt', '.yml')
date = minutes[/\d{4}_\d\d_\d\d/].gsub('_', '-')
minutes = YAML.load_file(File.join(AGENDA_WORK, minutes)) rescue {}
minutes.each do |title, secnotes|
  next unless secnotes.is_a? String
  secnotes.scan(pattern).each do |owner, text|
    text = text.reflow(6, 72).strip
    actions << {owner: owner, text: text, status: nil, pmc: title, date: date}
  end
end

# get roll call info
roll = parsed.find {|item| item['title'] == 'Roll Call'}['people']

# return results
_date date
_actions actions
_names roll.map {|id, person| person[:name].split(' ').first}.sort.uniq
