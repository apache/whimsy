#
# Publish approved minutes on the public web site
#

require 'date'
require 'whimsy/asf/svn'

CONTENT = 'asf/infrastructure/site/trunk/content'
BOARD_SITE = ASF::SVN["#{CONTENT}/foundation/board"]
MINUTES = ASF::SVN["#{CONTENT}/foundation/records/minutes"]
BOARD_PRIVATE = ASF::SVN['foundation_board']
CALENDAR = File.join(BOARD_SITE, 'calendar.mdtext')

# update from svn
[MINUTES, BOARD_SITE, BOARD_PRIVATE].each do |dir| 
  Dir.chdir(dir) {`svn cleanup`; `svn up`}
end

calendar = File.read(CALENDAR)

# clean up summary
@summary = @summary.gsub(/\r\n/,"\n").sub(/\s+\Z/,'') + "\n"

# extract date and year from minutes
@date.untaint if @date =~ /^\d+_\d+_\d+$/
date = Date.parse(@date.gsub('_', '-'))
year = date.year
fdate = date.strftime("%d %B %Y")

# add year header
unless calendar.include? "##{year}"
  calendar[/^()#.*Board meeting minutes #/,1] =
    "# #{year} Board meeting minutes # {##{year}}\n\n"
end

# add summary
if calendar.include? "\n- [#{fdate}]"
  calendar.sub! /\n-\s+\[#{fdate}\].*?(\n[-#])/m, "\n" + @summary + '\1'
else
  calendar[/# #{year} Board meeting minutes #.*\n()/,1] = "\n" + @summary
end

# remove from calendar
calendar.sub! /^(\s*[*-]\s+#{fdate}\s*?\n)/, ''

#Commit the Minutes
ASF::SVN.update MINUTES, @message, env, _ do |tmpdir|
  yeardir = File.join(tmpdir, year.to_s).untaint
  _.system "svn up #{yeardir}"

  unless Dir.exist? yeardir
    _.system "mkdir #{yeardir}"
    _.system "svn add #{yeardir}"
  end

  if not File.exist? File.join(yeardir, "board_minutes_#{@date}.txt")
    _.system "cp #{BOARD_PRIVATE}/board_minutes_#{@date}.txt #{yeardir}"
    _.system "svn add #{yeardir}/board_minutes_#{@date}.txt"
  end
end

# Update the Calendar
if File.read(CALENDAR) != calendar
  ASF::SVN.update CALENDAR, @message, env, _ do |tmpdir, old_contents|
    calendar
  end
end

# Clean up board directory
ASF::SVN.update BOARD_PRIVATE, @message, env, _ do |tmpdir|
  _.system "svn up #{tmpdir}/board_minutes_#{@date}.txt"
  if File.exist? "#{tmpdir}/board_minutes_#{@date}.txt"
    _.system "svn rm #{tmpdir}/board_minutes_#{@date}.txt"
  end
  
  _.system "svn up #{tmpdir}/board_agenda_#{@date}.txt"
  if File.exist? "#{tmpdir}/board_agenda_#{@date}.txt"
    _.system "svn up --depth empty #{tmpdir}/archived_agendas"
    _.system "svn mv #{tmpdir}/board_agenda_#{@date}.txt " +
      "#{tmpdir}/archived_agendas"
  end
end

Dir.chdir(BOARD_PRIVATE) {Dir['board_minutes_*.txt'].sort}
