#!/usr/bin/env ruby

"""
Publish minutes:
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

$LOAD_PATH.unshift '/srv/whimsy/lib'
require 'wunderbar'
require 'date'
require 'whimsy/asf'
require 'shellwords'

secretary = ASF::Service['asf-secretary'].members.map(&:id).include? $USER

unless secretary 
  print "Status: 401 Unauthorized\r\n"
  print "WWW-Authenticate: Basic realm=\"ASF Secretarial team\"\r\n\r\n"
  exit
end

BOARD_SITE = ASF::SVN['site-board']
MINUTES = ASF::SVN['minutes']
BOARD_PRIVATE = ASF::SVN['foundation_board']
CALENDAR = File.join(BOARD_SITE, 'calendar.mdtext')

_html do
  _head do
    _title 'Commit Minutes'
    _style %{
      ._stdin {display: none}
      ._stdout, ._stderr {margin: 0}
      ._stderr {color: red}
      li {margin: 0.5em}
    }
  end
  _body? do
    # update from svn
    [MINUTES, BOARD_SITE, BOARD_PRIVATE].each do |dir|
      ASF::SVN.svn('cleanup', dir)
      ASF::SVN.svn('update', dir) # TODO does this need auth?
    end

    calendar = File.read(CALENDAR)

    # clean up summary; extract date and year from it
    @summary = @summary.gsub(/\r\n/,"\n").sub(/\s+\Z/,'') + "\n"
    date = @summary[/\[(.*?)\]/,1]
    year = date.split(' ').last

    # add year header before the first one
    unless calendar.include? '#'+year
      calendar[/^()#.*Board meeting minutes #/,1] =
        "# #{year} Board meeting minutes # {##{year}}\n\n"
    end

    # add summary
    if calendar.include? "\n- [#{date}]"
      calendar.sub! /\n-\s+\[#{date}\].*?(\n[-#])/m, "\n" + @summary + '\1'
    else
      calendar[/# #{year} Board meeting minutes #.*\n()/,1] = "\n" + @summary
    end

    # remove from calendar
    calendar.sub! /^(\s+-\s+#{date}\s*\n)/, ''

    # parse and cleanup input
    date = Date.parse(date).strftime("%Y_%m_%d")
    year.untaint if year =~ /^\d+$/
    message = Shellwords.escape(@message).untaint

    _h1 'Publish the Minutes'

    _h2 'Commit the Minutes'
    Dir.chdir MINUTES do
      unless Dir.exist? year
        _.system ['mkdir', year]
        ASF::SVN.svn_('add', year, _)
      end
      minutes_date = "board_minutes_#{date}.txt"
      minutes_year = File.join(year, minutes_date)
      if File.exist? minutes_year
        _p "#{minutes_year} already exists", class: '_stderr'
      else
        _.system ['cp', File.join(BOARD_PRIVATE, minutes_date), year]
        ASF::SVN.svn_('add', minutes_year, _)
        _p
        ASF::SVN.svn_('commit', year, _, {msg: message, user: $USER, password: $PASSWORD})

        File.unlink 'svn-commit.tmp' if File.exist? 'svn-commit.tmp'

        out,err = ASF::SVN.svn('status', MINUTES) # Need to use svn() here, not svn_()
        unless out.empty?
          ASF::SVN.svn_('status', MINUTES, _)
          raise "svn failure"
        end
      end
    end

    _h2 'Update the Calendar'
    if File.read(CALENDAR) == calendar
      _p "#{File.basename CALENDAR} already up to date", class: '_stderr'
    else
      File.open(CALENDAR, 'w') {|fh| fh.write calendar}
      ASF::SVN.svn_('diff', CALENDAR)
      _p
      ASF::SVN.svn_('commit', CALENDAR, _, {msg: message, user: $USER, password: $PASSWORD})

      out, err = ASF::SVN.svn('status', BOARD_SITE) # Need to use svn() here, not svn_()
      unless out.empty?
        ASF::SVN.svn_('status', BOARD_SITE, _)
        raise "svn failure"
      end
    end

    _h2 'Clean up board directory'
    Dir.chdir BOARD_PRIVATE do
      updated = false

      if File.exist? minutes_date
        ASF::SVN.svn_('rm', minutes_date,_)
        updated = true
      end
      
      agenda_date = "board_agenda_#{date}.txt"
      if File.exist? agenda_date
        ASF::SVN.svn_('mv', [agenda_date, 'archived_agendas'], _)
        updated = true
      end

      if updated
        _p
        ASF::SVN.svn_('commit', BOARD_PRIVATE, _, {msg: message, user: $USER, password: $PASSWORD})

        out,err = ASF::SVN.svn('status', BOARD_PRIVATE) # Need to use svn() here, not svn_()
        unless out.empty?
          ASF::SVN.svn_('status', BOARD_PRIVATE, _)
          raise "svn failure"
        end
      else
        _p "Nothing to clean up", class: '_stderr'
      end
    end

    _h2 'Publish www site'
    _a 'Proceed to CMS', href: 'https://cms.apache.org/www/publish'
  end
end

