##   Licensed to the Apache Software Foundation (ASF) under one or more
##   contributor license agreements.  See the NOTICE file distributed with
##   this work for additional information regarding copyright ownership.
##   The ASF licenses this file to You under the Apache License, Version 2.0
##   (the "License"); you may not use this file except in compliance with
##   the License.  You may obtain a copy of the License at
## 
##       http://www.apache.org/licenses/LICENSE-2.0
## 
##   Unless required by applicable law or agreed to in writing, software
##   distributed under the License is distributed on an "AS IS" BASIS,
##   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
##   See the License for the specific language governing permissions and
##   limitations under the License.

#
# Bulk apply comments and pre-approvals to agenda file
#

user = env.user
user = user.dup.untaint if user =~ /\A\w+\z/
updates = YAML.load_file("#{AGENDA_WORK}/#{user}.yml")

agenda_file = updates['agenda']

Agenda.update(agenda_file, @message) do |agenda|
  # refetch to make sure the data is fresh (handles retries, locks, etc...)
  updates = YAML.load_file("#{AGENDA_WORK}/#{user}.yml")

  approved = updates['approved']
  unapproved = updates['unapproved'] || []
  flagged = updates['flagged'] || []
  unflagged = updates['unflagged'] || []
  comments = updates['comments']
  initials = @initials
  parsed = nil

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

      # remove initials from the report if unapproved
      elsif unapproved.include? attachment
        approvals = approvals.strip.split(/(?:,\s*|\s+)/)
        if approvals.delete(initials)
          if approvals.empty?
            match[/approved:(.*?)\n/, 1] = ""
          else
            match[/approved: (.*?)\n/, 1] = approvals.join(', ')
          end
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

    # flag/unflag reports
    unless flagged.empty? and unflagged.empty?
      parsed = ASF::Board::Agenda.parse(agenda, true)
      flagged_reports = Hash[agenda[/ \d\. Committee Reports.*?\n\s+A\./m].
        scan(/# (.*?) \[(.*)\]/).
        map {|pmc, flags| [pmc, flags.split(/,\s+/)]}]

      parsed.each do |item|
        if flagged.include? item[:attach]
          title = item['title']

          flagged_reports[title] ||= []
          unless flagged_reports[title].include? initials
            flagged_reports[title].push initials
          end

        elsif unflagged.include? item[:attach]
          title = item['title']
          if flagged_reports[title]
            flagged_reports[title].delete(initials)
            flagged_reports.delete(title) if flagged_reports[title].empty?
          end
        end
      end

      # update agenda
      agenda.sub!(/ \d\. Committee Reports.*?\n\s+A\./m) do |flags|
        if flags =~ /discussion:\n\n()/
          flags.gsub! /\n +# .*? \[.*\]/, ''
          flags[/discussion:\n\n()/, 1] = flagged_reports.sort.
            map {|pmc, who| "        # #{pmc} [#{who.join(', ')}]\n"}.join
          flags.sub!(/\n+(\s+)A\.\z/) {"\n\n#{$1}A."}
        end

        flags
      end
    end

    # action item status updates
    if updates['status']
      parsed ||= ASF::Board::Agenda.parse(agenda, true)
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

  # apply operations comments to the President's report
  operations = Range.new(*agenda.scan(
    /\s*Additionally, please see Attachments (\d) through (\d)\./).first)
  operations.each do |attachment|
    if comments.include? attachment
      office = agenda[
        /^Attachment #{attachment}: Report from the (.*?)  \[/, 1]
      office.sub! /^VP of /, ''
      office.sub! /^Apache /, ''

      width = 79-13-initials.length
      text = "[#{office}] #{comments[attachment]}"
      text = text.reflow(13+initials.length, width)
      text[/ *(#{' '*(initials.length+2)})/,1] = "#{initials}: "

      agenda.sub!(patterns['4']) do |match|
        match[/\n()\s{9}\]/,1] = "#{text}\n"
        match
      end
    end
  end

  # return updated agenda
  agenda
end

# backup pending file, then clear approved and comments lists
_pending Pending.update(env.user) {|pending|
  File.rename "#{AGENDA_WORK}/#{user}.yml", "#{AGENDA_WORK}/#{user}.bak"
  pending['approved'].clear
  pending['unapproved'].clear
  pending['flagged'].clear
  pending['unflagged'].clear
  pending['comments'].clear
  pending['status'].clear if pending['status']
}
