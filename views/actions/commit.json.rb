#
# Bulk apply comments and pre-approvals to agenda file
#

user = env.user
user = user.dup.untaint if user =~ /\A\w+\Z/
updates = YAML.load_file("#{AGENDA_WORK}/#{user}.yml")

agenda_file = updates['agenda']

Agenda.update(agenda_file, @message) do |agenda|
  approved = updates['approved']
  comments = updates['comments']
  initials = @initials

  patterns = {
   # Committee Reports
   '' => /
     ^\s{7}See\sAttachment\s\s?(\w+)[^\n]*?\s+
     \[\s[^\n]*\s*approved:\s*?(.*?)
     \s*comments:(.*?)\n\s{9}\]
     /mx,

   # Meeting Minutes
   '3' => /
     ^\s{4}(\w)\.\sThe\smeeting\sof.*?
     \[\s[^\n]*\s*approved:\s*?(.*?)
     \s*comments:(.*?)\n\s{9}\]
     /mx,

   # Executive Officers: only the president has comments
   '4' => /
     ^\s{4}(\w)\.\sPresident\s\[.*?
     \[\s*comments:()(.*?)\n\s{9}\]
     /mx,
  }

  # iterate over patterns, matching attachments to approvals and comments
  patterns.each do |prefix, pattern|
    agenda.gsub!(pattern) do |match|
      attachment, approvals = prefix + $1, $2

      # add initials to the report if approved
      if approved.include? attachment
        approvals = approvals.strip.split(/(?:,\s*|\s+)/)
        if approvals.include? initials
          # do nothing
        elsif approvals.empty?
          match[/approved:(\s*)\n/, 1] = " #{initials}"
        else
          match[/approved:.*?()\n/, 1] = ", #{initials}"
        end
      end

      # add comments to this report
      if comments.include? attachment
        width = 79-13-initials.length
        text = comments[attachment].reflow(13+initials.length, width)
        text[/ *(#{' '*(initials.length+2)})/,1] = "#{initials}: "
        match[/\n()\s{9}\]/,1] = "#{text}\n"
      end

      match
    end

    # action item status updates
    if updates['status']
      parsed = ASF::Board::Agenda.parse(agenda, true)
      actions = parsed.find {|item| item['title'] == 'Action Items'}

      require 'stringio'
      replacement = StringIO.new
      actions['actions'].each do |action|
        # check for updates for this action item
        updates['status'].each do |update|
          match = true
          action.each do |name, value|
            match = false if name != :status and update[name] != action[name]
          end
          action = update if match
        end
        
        # format action item
        replacement.puts "* #{action[:owner]}: #{action[:text]}"

        if action[:date] or action[:pmc]
          replacement.print '      ['
          replacement.print " #{action[:pmc]}" if action[:pmc]
          replacement.print " #{action[:date]}" if action[:date]
          replacement.puts ' ]'
        end

        replacement.print "      Status:"
        replacement.print " #{action[:status]}" unless action[:status].empty?
        replacement.puts
        replacement.puts
      end

      # replace entire section
      agenda[/^ ?\d+\. Review Outstanding Action Items\n\n(.*?\n\n)\s?\d/m, 1] =
        replacement.string.gsub(/^(.)/, '    \1')
    end
  end

  # return updated agenda
  agenda
end

# backup pending file, then clear approved and comments lists
pending = Pending.get(env.user)
File.rename "#{AGENDA_WORK}/#{user}.yml", "#{AGENDA_WORK}/#{user}.bak"
pending['approved'].clear
pending['comments'].clear
pending['status'].clear
Pending.put(env.user, pending)
_pending pending
