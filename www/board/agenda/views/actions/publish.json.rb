
"""

Publish approved minutes on the public web site

- clean up site-board, minutes, foundation-board checkouts
- read calendar and update text
  - add year index
  - add summary
  - remove ?
- commit minutes (public repo):
  - create/add the yearly folder if necessary
  - if the public minutes do not already exist:
    - copy private minutes to the yearly folder
    - svn add them
    - commit the updated yearly folder
    - check for leftover errors
- commit updated calendar:
  - if text has changed:
    - svn diff
    - svn commit
    - check for leftover errors
- clean up board directory (private repo)
  - remove minutes if they exist
  - archive agenda if it exists
  - commit changes if any

"""

require 'date'
require 'whimsy/asf/svn'

MINUTES = ASF::SVN['minutes']
BOARD_PRIVATE = ASF::SVN['foundation_board']

# update from svn
[MINUTES, BOARD_PRIVATE].each do |dir|
  ASF::SVN.svn('cleanup', dir)
  ASF::SVN.svn('update', dir) # TODO: does this need auth?
end

# clean up summary
@summary = @summary.gsub(/\r\n/,"\n").sub(/\s+\Z/,'') + "\n"

raise ArgumentError, "Invalid date #{@date}" unless @date =~ /\A\d+_\d+_\d+\z/

# extract date and year from minutes
date = Date.parse(@date.gsub('_', '-'))
year = date.year
fdate = date.strftime("%d %B %Y")

minutes = "board_minutes_#{@date}.txt"

#Commit the Minutes
ASF::SVN.update MINUTES, @message, env, _ do |tmpdir|
  yeardir = File.join(tmpdir, year.to_s)
  ASF::SVN.svn_('update', yeardir, _) # TODO does this need auth?

  unless Dir.exist? yeardir
    _.system('mkdir', yeardir)
    ASF::SVN.svn_('add', yeardir, _)
  end

  year_minutes = File.join(yeardir, minutes)
  unless File.exist? year_minutes
    _.system('cp', File.join(BOARD_PRIVATE, minutes), yeardir)
    ASF::SVN.svn_('add', year_minutes, _)
  end
end

# Sample of the calendar.md layout
#
# Title: ...
# Notice: AL2.0
#
# Introductory paragraph...
#
# [2020](calendar.html#2020) |
# ...
# [Pre-organization meetings](calendar-1999-2004.html#preorg)
#
# # 2020 Board meeting minutes  {#2020}
#
# - [17 June 2020](../records/minutes/2020/board_minutes_2020_06_17.txt)
#     * ...
#     * ...
# - [20 May 2020](../records/minutes/2020/board_minutes_2020_05_20.txt)
#     * ...
# ...

# Update the Calendar from SVN
ASF::SVN.update ASF::SVN.svnpath!('site-board', 'calendar.md' ), @message, env, _ do |_tmpdir, calendar|
  # add year index
  unless calendar.include? "[#{year}](calendar.html##{year}) |"
    calendar[/^()\[.*\(calendar.html/, 1] =
      "[#{year}](calendar.html##{year}) |\n"
  end

  # add year header
  unless calendar.include? "# #{year} Board meeting minutes"
    calendar[/^()#.*Board meeting minutes /, 1] =
      "# #{year} Board meeting minutes {##{year}}\n\n"
  end

  # add summary
  if calendar.include? "\n- [#{fdate}]"
    calendar.sub! /\n-\s+\[#{fdate}\].*?(\n[-#])/m, "\n" + @summary + '\1'
  else
    calendar[/# #{year} Board meeting minutes .*\n()/, 1] = "\n" + @summary
  end

  # remove from calendar
  calendar.sub! /^(\s*[*-]\s+#{fdate}\s*?\n)/, ''

  calendar
end

# Clean up board directory
ASF::SVN.update BOARD_PRIVATE, @message, env, _ do |tmpdir|
  minutes_path = File.join(tmpdir, minutes)
  ASF::SVN.svn_('update', minutes_path, _)
  if File.exist? minutes_path
    ASF::SVN.svn_('rm', minutes_path, _)
  end

  agenda_path = File.join(tmpdir, "board_agenda_#{@date}.txt")
  ASF::SVN.svn_('update', agenda_path, _)
  if File.exist? agenda_path
    agenda_archive = File.join(tmpdir, 'archived_agendas')
    ASF::SVN.svn_('update', agenda_archive, _, {depth: 'empty'})
    ASF::SVN.svn_('mv', [agenda_path, agenda_archive], _)
  end
end

Dir['board_minutes_*.txt', base: BOARD_PRIVATE].sort
