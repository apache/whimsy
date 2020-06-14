#
# Publish approved minutes on the public web site
#

require 'date'
require 'whimsy/asf/svn'

BOARD_SITE = ASF::SVN['site-board']
MINUTES = ASF::SVN['minutes']
BOARD_PRIVATE = ASF::SVN['foundation_board']
CALENDAR = File.join(BOARD_SITE, 'calendar.mdtext')

# update from svn
[MINUTES, BOARD_SITE, BOARD_PRIVATE].each do |dir|
  ASF::SVN.svn('cleanup', dir)
  ASF::SVN.svn('update', dir) # TODO: does this need auth?
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

minutes = "board_minutes_#{@date}.txt"

#Commit the Minutes
ASF::SVN.update MINUTES, @message, env, _ do |tmpdir|
  yeardir = File.join(tmpdir, year.to_s).untaint
  _.system "svn up #{yeardir}"

  unless Dir.exist? yeardir
    _.system "mkdir #{yeardir}"
    _.system "svn add #{yeardir}"
  end

  year_minutes = File.join(yeardir, minutes)
  if not File.exist? year_minutes
    _.system "cp #{File.join(BOARD_PRIVATE, minutes)} #{yeardir}"
    _.system "svn add #{year_minutes}"
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
  minutes_path = File.join(tmpdir, minutes)
  _.system "svn up #{minutes_path}"
  if File.exist? minutes_path
    _.system "svn rm #{minutes_path}"
  end
  
  agenda_path = File.join(tmpdir, "board_agenda_#{@date}.txt")
  _.system "svn up #{agenda_path}"
  if File.exist? agenda_path
    agenda_archive = File.join(tmpdir, 'archived_agendas')
    _.system "svn up --depth empty #{agenda_archive}"
    _.system "svn mv #{agenda_path} #{agenda_archive}"
  end
end

Dir.chdir(BOARD_PRIVATE) {Dir['board_minutes_*.txt'].sort}
