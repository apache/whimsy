class Minutes
  def self.draft(agenda_txt, minutes_yaml)
    minutes = File.read(agenda_txt)
    @@notes = YAML.load_file(minutes_yaml) rescue {}

    minutes.mreplace(/\n\s1\.\sCall\sto\sorder\n+(.*?:)\n\n
                     ((?:^\s{12}[^\n]*\n+)+\n)
                     (.*?)\n\n\s2\.\sRoll\sCall/mx) do |meeting, number, backup|
      start = notes('Call to order') || '??:??'
      meeting.gsub! "is scheduled", "was scheduled"
      meeting.gsub! "will begin as", "began at"
      meeting.gsub! "soon thereafter that", "#{start} when"
      meeting.gsub! "quorum is", "quorum was"
      meeting.gsub! "will be", "was"
      meeting.gsub! %r{:\z}, "."
      backup.gsub! "will be", "was"
      [meeting.reflow(4, 64), '', backup.reflow(4, 68)]
    end

    minutes.sub! %r{^ +ASF members are welcome to attend board meetings.*?\n\n}m,
      ''

    minutes.mreplace(/\n\s2\.\sRoll\sCall\n\n
                     (.*?)\n\n+\s3.\sMinutes
                     /mx) do |rollcall|
      if notes('Roll Call')
        notes('Roll Call').gsub(/\r\n/, "\n").gsub(/\n*\Z/, '').
          gsub(/^([^\n])/, '    \1')
      else
        rollcall.gsub(/ \(expected.*?\)/, '')
      end
    end

    minutes.mreplace(/\n\s3\.\sMinutes\sfrom\sprevious\smeetings\n\n
                     (.*?\n\n)
                     \s4\.\sExecutive\sOfficer\sReports
                     /mx) do |prior_minutes|
      prior_minutes.mreplace(/\n\s+(\w)\.\sThe\smeeting\sof\s(.*?)\n.*?\n
                             (\s{7}\[.*?\])\n\n
                     /mx) do |attach, title, pub_minutes|
        notes = notes(title)
        if notes and !notes.empty?
          notes = 'Approved by General Consent.' if notes == 'approved'
          notes = 'Tabled.' if notes == 'tabled'
          [attach, title, notes.reflow(7,62)]
        else
          [attach, title, '       Tabled.']
        end
      end
    end

    minutes.mreplace(/\n\s4\.\sExecutive\sOfficer\sReports\n
                     (\n.*?\n\n)
                     \s5\.\sAdditional\sOfficer\sReports
                     /mx) do |reports|
      reports.mreplace(/\n\s\s\s\s(\w)\.\s(.*?)\[.*?\](.*?)
                     ()(?:\n+\s\s\s\s\w\.|\n\n\z)
                     /mx) do |section, title, report, comments|
        notes = notes(title)
        if notes and !notes.empty?
          [section, title, report, "\n\n" + notes.reflow(7,62)]
        elsif report.strip.empty?
          [section, title, report, "\n\n       No report was submitted."]
        else
          [section, title, report, ""]
        end
      end
    end

    minutes.mreplace(/\n\s5\.\sAdditional\sOfficer\sReports\n
                     (\n.*?\n\n)
                     \s7\.\sSpecial\sOrders
                     /mx) do |reports|
      reports.mreplace(/
        \n\s\s\s\s\s?(\w+)\.\s([^\n]*?)   # section, title
        \[([^\n]+)\]\n\n                  # owners
        \s{7}See\s\s?Attachment\s\s?(\w+)[^\n]* # attach (title)
        (\s+\[\s.*?approved:\s*?.*?       # approved
        \s*comments:.*?\n\s{9}\])         # comments
      /mx) do |section, title, owners, attach, comments|
        notes = notes(title.sub('VP of','').strip)
        if notes and !notes.empty?
          comments = "\n\n" + notes.to_s.reflow(7,62)
        else
          comments = ''
        end
        [section, title, owners, attach, comments]
      end
    end

    minutes.mreplace(/\n\s7\.\sSpecial\sOrders\n
                     (.*?)
                     \n\s8\.\sDiscussion\sItems
                     /mx) do |reports|
      break if reports.empty?
      reports.mreplace(/\n\s\s\s\s(\w)\.(.*?)\n(.*?)()\s+(?:\s*\n\s\s\s\s\w\.|\z)
                     /mx) do |section, title, order, comments|
        order.sub! %r{\n       \[.*?\n         +\]\n}m, ''
        notes = notes(title.strip)
        if !notes or notes.empty? or notes.strip == 'tabled'
          notes = "was tabled."
        elsif notes == 'unanimous'
          notes = "was approved by Unanimous Vote of the directors present."
        end
        notes = "Special Order 7#{section}, #{title}, " + notes
        order += "\n" unless order =~ /\n\Z/
        [section, title, order, "\n" + notes.reflow(7,62)]
      end
    end

    minutes.mreplace(/\n\s8\.\sDiscussion\sItems
                     (.*?)
                     \n\s9\.\s.*Action\sItems
                     /mx) do |reports|
      break unless reports =~ /\n\s{3,5}[A-Z]\.\s/
      reports.mreplace(/\n\s\s\s\s(\w)\.(.*?)\n(.*?)()\s+(?:\s*\n\s\s\s\s\w\.|\z)
                     /mx) do |section, title, item, comments|
        item.sub! %r{\n       \[.*?\n         +\]\n}m, ''
        item += "\n" unless item =~ /\n\Z/
        notes = notes(title.strip) || ''
        [section, title, item, "\n" + notes.reflow(7,70)]
      end
    end

    minutes.mreplace(/
      ^((?:\s[89]|1\d)\.)\s
      (.*?)\n
      (.*?)
      (?=\n[\s1]\d\.|\n===)
    /mx) do |attach, title, comments|
      notes = notes(title)

      if notes and !notes.empty?
        if title =~ /Action Items/
          comments = notes.gsub(/\r\n/,"\n").gsub(/^/,'    ')
        elsif title == 'Adjournment'
          comments = "\n    Adjourned at #{notes} UTC\n"
        else
          comments += "\n" + notes.to_s.reflow(4,68) + "\n"
        end
      elsif title == 'Adjournment'
        comments = "\n    Adjourned at ??:?? UTC\n"
      end
      [attach, title, comments]
    end

    missing = minutes.scan(/^Attachment (\w\w?):.*\s*\n---/).flatten
    missing.each do |attach|
      minutes.sub! %r{^(\s+)See Attachment #{Regexp.escape(attach)}$}, '\1No report was submitted.'
    end

    minutes.sub! 'Minutes (in Subversion) are found under the URL:',
      'Published minutes can be found at:'

    minutes.sub! ASF::SVN.svnpath!('foundation_board'),
      'http://www.apache.org/foundation/board/calendar.html'

    minutes.sub!(/ \d\. Committee Reports.*?\n\s+A\./m) do |heading|
      heading.sub('reports require further', 'reports required further')
    end

    minutes[/^() 5. Additional Officer Reports/,1] =
      "    Executive officer reports approved as submitted by General Consent.\n\n"

    minutes[/^() 6. Committee Reports/,1] =
      "    Additional officer reports approved as submitted by General Consent.\n\n"

    minutes[/^() 7. Special Orders/,1] =
      "    Committee reports approved as submitted by General Consent.\n\n"

    minutes.sub! 'Meeting Agenda', 'Meeting Minutes'
    minutes.sub! %r{^End of agenda}, 'End of minutes'

    # remove block of lines (and preceding whitespace including blank lines)
    # where the first line starts with <private> and the last line ends with
    # </private>.
    minutes.gsub! %r{^\s*<private>.*?<\/private>\s*?\n}mi, ''

    # remove inline <private>...</private> sections (and preceding spaces
    # and tabs) where the <private> and </private> are on the same line.
    minutes.gsub! %r{[ \t]*<private>.*?<\/private>}i, ''

    minutes.gsub! %r{\n( *)\[ comments:.*?\n\1 ? ?\]}m, ''

    minutes
  end

  def self.notes(index)
    index = index.strip
    return @@notes[index] if @@notes[index]

    index.sub! %r{^Report from the VP of }, ''
    index.sub! %r{^Report from the }, ''
    index.sub! %r{^Status report for the }, ''
    index.sub! %r{^Resolution to }, ''
    index.sub! %r{^Apache }, ''
    index.sub! %r{\sTeam$}, ''
    index.sub! %r{\sCommittee$}, ''
    index.sub! %r{\sthe\s}, ' '
    index.sub! %r{\sApache\s}, ' '
    index.sub! %r{\sCommittee\s}, ' '
    index.sub! %r{\sProject$}, ''
    index.sub! %r{\sPMC$}, ''
    index.sub! %r{\sProject\s}, ' '

    @@notes[index]
  end
end
