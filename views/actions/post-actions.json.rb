#
# Post list of action items
#

Agenda.update(@agenda, @message) do |agenda|
  # render all uncompleted actions
  text = ''
  @actions.each do |action|
    next if action['complete']
    text += "* #{action['owner']}: #{action['text']}\n"
    text += "      [ #{action['pmc']} #{action['date']} ]\n"
    text += "      Status:\n\n"
  end

  # insert into the agenda
  agenda[/^\s+\d+\.\sReview\sOutstanding\s Action\s Items(\n\s*\n)
    \s*\d+\.\sUnfinished\sBusiness/x, 1] = text.gsub(/^/, '    ')

  # return updated agenda
  agenda
end
