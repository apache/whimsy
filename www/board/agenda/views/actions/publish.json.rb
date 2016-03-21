#
# Publish approved minutes on the public web site
#

require 'date'
require 'whimsy/asf/svn'

CONTENT = 'asf/infrastructure/site/trunk/content'
BOARD_SITE = ASF::SVN["#{CONTENT}/foundation/board"]
MINUTES = ASF::SVN["#{CONTENT}/foundation/records/minutes"]
BOARD_PRIVATE = ASF::SVN['private/foundation/board']
CALENDAR = "#{BOARD_SITE}/calendar.mdtext"

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
calendar.sub! /^(\s*-\s+#{fdate}\s*\n)/, ''

#Commit the Minutes
ASF::SVN.update MINUTES, @message, env, _ do |tmpdir, old_contents|
  tmp = File.join(tmpdir, File.basename(MINUTES), year.to_s).untaint

  unless Dir.exist? tmp
    _.system "mkdir #{tmp}"
    _.system "svn add #{tmp}"
  end

  if not File.exist? "#{year}/board_minutes_#{@date}.txt"
    _.system "cp #{BOARD_PRIVATE}/board_minutes_#{@date}.txt #{tmp}"
    _.system "svn add #{tmp}/board_minutes_#{@date}.txt"
  end

  nil
end

# Update the Calendar
if File.read(CALENDAR) != calendar
  ASF::SVN.update CALENDAR, @message, env, _ do |tmpdir, old_contents|
    calendar
  end
end

# Clean up board directory
ASF::SVN.update BOARD_PRIVATE, @message, env, _ do |tmpdir, old_contents|
  tmp = File.join(tmpdir, File.basename(BOARD_PRIVATE)).untaint

  if File.exist? "#{tmp}/board_minutes_#{@date}.txt"
    _.system "svn rm #{tmp}/board_minutes_#{@date}.txt"
  end
  
  if File.exist? "#{tmp}/board_agenda_#{@date}.txt"
    _.system "svn mv #{tmp}/board_agenda_#{@date}.txt #{tmp}/archived_agendas"
  end

  nil
end

Dir.chdir(BOARD_PRIVATE) {Dir['board_minutes_*.txt'].sort}
