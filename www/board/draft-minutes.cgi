#!/usr/bin/ruby1.9.1
require 'yaml'
require 'wunderbar'
require 'shellwords'
require 'date'
require '/var/tools/asf'

ENV['HOME'] = ENV['DOCUMENT_ROOT']
SVN_FOUNDATION_BOARD = ASF::SVN['private/foundation/board']
MINUTES_WORK = '/var/tools/data'

secretary = %w(clr rubys).include? $USER

user = ASF::Person.new($USER)
unless secretary or user.asf_member? or ASF.pmc_chairs.include?  user
  print "Status: 401 Unauthorized\r\n"
  print "WWW-Authenticate: Basic realm=\"ASF Members and Officers\"\r\n\r\n"
  exit
end

request = ENV['REQUEST_URI'].split('?').first

if request =~ /\/draft-minutes.*\/(\d\d\d\d[-_]\d\d[-_]\d\d)(\/|$)/
  date = $1.gsub('-','_')
elsif request =~ /\/draft-minutes.*\/(\d\d\d\d[-_]\d\d)(\/|$)/
  date = $1.gsub('-','_') + '_*'
elsif request =~ /\/draft-minutes.*\/(\d\d)(\/|$)/
  date = '*_' + $1.gsub('-','_') + '_*'
elsif request =~ /\/draft-minutes.*\/(\d\d[-_]\d\d)(\/|$)/
  date = '*_' + $1.gsub('-','_')
else
  date = '*'
end

agenda_txt = Dir["#{SVN_FOUNDATION_BOARD}/board_agenda_#{date.untaint}*.txt"].
  sort.last.untaint
minutes_yaml = MINUTES_WORK + '/' + File.basename(agenda_txt).
  sub('_agenda_','_minutes_').sub('.txt','.yml')

minutes = File.read(agenda_txt)
$notes = YAML.load_file(minutes_yaml) rescue {}

def notes(index)
  index = index.strip
  index.sub! /^Report from the VP of /, ''
  index.sub! /^Report from the /, ''
  index.sub! /^Status report for the /, ''
  index.sub! /^Resolution to /, ''
  index.sub! /^Apache /, ''
  index.sub! /\sTeam$/, ''
  index.sub! /\sCommittee$/, ''
  index.sub! /\sthe\s/, ' '
  index.sub! /\sApache\s/, ' '
  index.sub! /\sCommittee\s/, ' '
  index.sub! /\sProject$/, ''
  index.sub! /\sPMC$/, ''
  index.sub! /\sProject\s/, ' '

  $notes[index]
end

class String
  def mreplace regexp, &block
    matches = []
    offset = 0
    while self[offset..-1] =~ regexp
      matches << [offset, $~]
      offset += $~.end($~.size - 1)
    end
    raise 'unmatched' if matches.empty?

    matches.reverse.each do |offset, match|
      slice = self[offset...-1]
      send = (1...match.size).map {|i| slice[match.begin(i)...match.end(i)]}
      if send.length == 1
        recv = block.call(send.first)
        self[offset+match.begin(1)...offset+match.end(1)] = recv
      else
        recv = block.call(*send)
        next unless recv
        (1...match.size).map {|i| [match.begin(i), match.end(i), i-1]}.sort.
          reverse.each do |start, fin, i|
          self[offset+start...offset+fin] = recv[i]
        end
      end
    end
    self
  end

  def word_wrap(text, line_width=80)
    text.split("\n").collect do |line|
      line.length > line_width ?  line.gsub(/(.{1,#{line_width}})(\s+|$)/, "\\1\n").strip : line
    end * "\n"
  end

  def reflow(indent, len)
    gsub!(/@(\w)/) {"AI: " + $1.upcase} # action items
    strip.split(/\n\s+\n/).map {|line|
      line.gsub!(/\s+/, ' ')
      line.strip!
      word_wrap(line, len).gsub(/^/, ' '*indent)
    }.join("\n")
  end
end

minutes.mreplace(/\n\s1.\sCall\sto\sorder\n+(.*?:)\n\n
                 ((?:^\s{12}[^\n]*\n)+\n)
                 (.*?)\n\n\s2.\sRoll\sCall/mx) do |meeting, number, backup|
  start = notes('Call to order') || '??:??'
  meeting.gsub! "is scheduled", "was scheduled"
  meeting.gsub! "will begin as", "began at"
  meeting.gsub! "soon thereafter that", "#{start} when"
  meeting.gsub! "quorum is", "quorum was"
  meeting.gsub! "will be", "was"
  meeting.gsub! /:\z/, "."
  backup.gsub! "will be", "was"
  [meeting.reflow(4,64), '', backup.reflow(4, 68)]
end

minutes.mreplace(/\n\s2.\sRoll\sCall\n\n
                 (.*?)\n\n+\s3.\sMinutes
                 /mx) do |rollcall|
  if notes('Roll Call')
    notes('Roll Call').gsub(/\r\n/,"\n").gsub(/\n*\Z/,'')
  else
    rollcall.gsub(/ \(expected.*?\)/, '')
  end
end

minutes.mreplace(/\n\s3.\sMinutes\sfrom\sprevious\smeetings\n\n
                 (.*?\n\n)
                 \s4.\sExecutive\sOfficer\sReports
                 /mx) do |prior_minutes|
  prior_minutes.mreplace(/\n\s+(\w)\.\sThe\smeeting\sof\s(.*?)\n.*?\n
                         (\s{7}\[.*?\])\n\n
                 /mx) do |attach, title, pub_minutes|
    notes = notes(title)
    if notes and !notes.empty?
      notes = 'Approved by General Consent.' if notes == 'approved'
      [attach, title, notes.reflow(7,62)]
    else
      [attach, title, '       Tabled.']
    end
  end
end

minutes.mreplace(/\n\s4.\sExecutive\sOfficer\sReports\n
                 (\n.*?\n\n)
                 \s5.\sAdditional\sOfficer\sReports
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

minutes.mreplace(/\n\s5.\sAdditional\sOfficer\sReports\n
                 (\n.*?\n\n)
                 \s7.\sSpecial\sOrders
                 /mx) do |reports|
  reports.mreplace(/
    \n\s\s\s\s\s?(\w+)\.\s([^\n]*?)   # section, title
    \[([^\n]+)\]\n\n                  # owners
    \s{7}See\s\s?Attachment\s\s?(\w+) # attach
    (\s+\[\sapproved:\s*?.*?          # approved
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

minutes.mreplace(/\n\s7.\sSpecial\sOrders\n
                 (.*?)
                 \n\s8.\sDiscussion\sItems
                 /mx) do |reports|
  break if reports.empty?
  reports.mreplace(/\n\s\s\s\s(\w)\.(.*?)\n(.*?)()(?:\n\s*\n\s\s\s\s\w\.|\n\z)
                 /mx) do |section, title, order, comments|
    order.sub! /\n       \[.*?\n         +\]\n/m, ''
    notes = notes(title.strip)
    if !notes or notes.empty? or notes.strip == 'tabled'
      notes = "was tabled."
    elsif notes == 'unanimous'
      notes = "was approved by Unanimous Vote of the directors present."
    end
    notes = "Special Order 7#{section}, #{title}, " + notes
    order += "\n" unless order =~ /\n\Z/
    [section, title, order, "\n" + notes.reflow(7,62) + "\n"]
  end
end

minutes.mreplace(/
  ^((?:\s[89]|\s9|1\d)\.)\s
  (.*?)\n
  (.*?)
  (?=\n[\s1]\d\.|\n===)
/mx) do |attach, title, comments|
  notes = notes(title)

  if notes and !notes.empty?
    if title =~ /Action Items/
      comments = notes.gsub(/\r\n/,"\n").gsub(/^/,'    ')
    elsif title =~ /Discussion Items/
      comments = notes.gsub(/^/,'    ')+ "\n"
    elsif title == 'Adjournment'
      if notes =~ /1[01]:\d\d/
        comments = "\n    Adjourned at #{notes} a.m. (Pacific)\n"
      elsif notes =~ /\d\d:\d\d/
        comments = "\n    Adjourned at #{notes} p.m. (Pacific)\n"
      else
        comments += "\n" + comments
      end
    else
      comments += "\n" + notes.to_s.reflow(4,68) + "\n"
    end
  elsif title == 'Adjournment'
    comments = "\n    Adjourned at ??:?? a.m. (Pacific)\n"
  end
  [attach, title, comments]
end

missing = minutes.scan(/^Attachment (\w\w?):.*\s*\n---/).flatten
missing.each do |attach|
  minutes.sub! /^(\s+)See Attachment #{attach}$/, '\1No report was submitted.'
end

minutes.sub! 'Minutes (in Subversion) are found under the URL:',
  'Published minutes can be found at:'

minutes.sub! 'https://svn.apache.org/repos/private/foundation/board/',
  'http://www.apache.org/foundation/board/calendar.html'

minutes[/^() 5. Additional Officer Reports/,1] =
  "    Executive officer reports approved as submitted by General Consent.\n\n"

minutes[/^() 6. Committee Reports/,1] =
  "    Additional officer reports approved as submitted by General Consent.\n\n"

minutes[/^() 7. Special Orders/,1] =
  "    Committee reports approved as submitted by General Consent.\n\n"

minutes.sub! 'Meeting Agenda', 'Meeting Minutes'
minutes.sub! /^End of agenda/, 'End of minutes'

minutes.gsub! /^\s*<private>.*?<\/private>\s*?\n/m, ''
minutes.gsub! /\n( *)\[ comments:.*?\n\1 ? ?\]/m, ''

_html do
  _head do
    _title 'Draft Meeting Minutes'
    _script src: '/jquery-min.js'
    _style %{
      pre {margin: 0}
      .ins {color: #060}
      .del {color: #800}
      .buttons {width: 56ex; text-align: center; margin: 1em}
      ._stderr {font-weight:bold; color: #F00}
      ._stdin:before {content: "$ "; color: blue}
      ._stdin {color: purple; margin-top: 1em}
      .log {background-color: #eedd82; border: 1px solid #000; border-radius:
      1em; padding: 1em}
      .log h3 {margin: 0}
      form {display: inline}
    }
  end

  _body? do
    minutes_txt = agenda_txt.sub('_agenda_', '_minutes_')

    if _.post? and not File.exist? minutes_txt and secretary
      Dir.chdir File.dirname(minutes_txt) do
        _div class: 'log' do
          _h3 'Transcript'
          _.system [
            'svn', 'cp', 
            File.basename(agenda_txt),
            File.basename(minutes_txt)
          ]

          File.open(minutes_txt, 'w') {|fh| fh.write minutes}

          _.system [
            'svn', 'commit', 
            '-m',  @message || "draft minutes for #{date}",
            ['--no-auth-cache'],
            (['--username', $USER, '--password', $PASSWORD] if $PASSWORD),
            File.basename(minutes_txt)
          ]
        end
      end
    end

    _div class: 'buttons' do

      _form do
        if @format == 'diff'
          _button 'Show Draft', type: "submit"
        else
          _input type: "hidden", name: "format", value: "diff"
          _button 'Show Differences', type: "submit"
        end
      end

      if secretary and not File.exist? minutes_txt
        date = Date.parse(minutes_txt[/(\d[\w+]+)/,1].gsub('_','-'))
        _form action: request, method: "post" do
          _input type: "hidden", name: "message",  id: 'message',
            value: "draft minutes for #{date}",
            'data-value' => "draft minutes for #{date.strftime('%B %d, %Y')}"
          _button 'Commit Draft', type: "submit", id: 'commit'
        end
      end

    end

    if not @format == 'diff'
      _pre minutes
    else
      require 'open3'
      require 'thread'
      semaphore = Mutex.new
      dest = agenda_txt.sub('_agenda_', '_minutes_')
      if File.exist? dest
        command = "diff -u - #{dest} \
          --label '#{File.basename(dest).ljust(32)} (draft)' \
          --label '#{File.basename(dest).ljust(32)} (subversion)'"
      else
        command = "diff -u #{agenda_txt} - \
          --label '#{File.basename(agenda_txt).ljust(32)} (subversion)' \
          --label '#{File.basename(dest).ljust(32)} (draft)'"
      end
      Open3.popen3(command) do |pin, pout, perr|
        [
          Thread.new do
            until pout.eof?
              out_line = pout.readline.chomp
              semaphore.synchronize do
                if out_line =~ /^\+/
                  _pre out_line, class: 'ins'
                elsif out_line =~ /^-/
                  _pre out_line, class: 'del'
                else
                  _pre out_line
                end
              end
            end
          end,

          Thread.new do
            until perr.eof?
              err_line = perr.readline.chomp
              semaphore.synchronize { _pre err_line, class: '_stderr' }
            end
          end,

          Thread.new do
            pin.write minutes
            pin.close
          end
        ].each {|thread| thread.join}
      end
    end

    _script %{
      $("#commit").click(function() {
        var message = prompt("Commit Message?", 
          $('#message').attr('data-value'));
        if (message) {
          $('#message').attr('value', message);
          return true;
        } else {
          return false;
        }
      });
    }
  end
end
