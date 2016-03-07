#!/usr/bin/ruby
require 'wunderbar'
require 'date'
require 'whimsy/asf'
require 'shellwords'

secretary = %w(clr rubys jcarman).include? $USER

unless secretary 
  print "Status: 401 Unauthorized\r\n"
  print "WWW-Authenticate: Basic realm=\"ASF Secretarial team\"\r\n\r\n"
  exit
end

CONTENT = 'asf/infrastructure/site/trunk/content'
BOARD_SITE = ASF::SVN["#{CONTENT}/foundation/board"]
MINUTES = ASF::SVN["#{CONTENT}/foundation/records/minutes"]
BOARD_PRIVATE = ASF::SVN['private/foundation/board']
CALENDAR = "#{BOARD_SITE}/calendar.mdtext"

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
      Dir.chdir(dir) {`svn cleanup`; `svn up`}
    end

    calendar = File.read(CALENDAR)

    # clean up summary; extract date and year from it
    @summary = @summary.gsub(/\r\n/,"\n").sub(/\s+\Z/,'') + "\n"
    date = @summary[/\[(.*?)\]/,1]
    year = date.split(' ').last

    # add year header
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
        _.system "mkdir #{year}"
        _.system "svn add #{year}"
      end
      if File.exist? "#{year}/board_minutes_#{date}.txt"
        _p "#{year}/board_minutes_#{date}.txt already exists", class: '_stderr'
      else
        _.system "cp #{BOARD_PRIVATE}/board_minutes_#{date}.txt #{year}"
        _.system "svn add #{year}/board_minutes_#{date}.txt"
        _p
        _.system [
          'svn', 'commit', '-m', message, year,
          ['--no-auth-cache', '--non-interactive'],
          (['--username', $USER, '--password', $PASSWORD] if $PASSWORD)
        ]

        File.unlink 'svn-commit.tmp' if File.exist? 'svn-commit.tmp'

        unless `svn st`.empty?
          _.system ['svn', 'status']
          raise "svn failure"
        end
      end
    end

    _h2 'Update the Calendar'
    Dir.chdir BOARD_SITE do
      if File.read(CALENDAR) == calendar
        _p "#{File.basename CALENDAR} already up to date", class: '_stderr'
      else
        File.open(CALENDAR, 'w') {|fh| fh.write calendar}
        _.system "svn diff #{File.basename CALENDAR}"
        _p
        _.system [
          'svn', 'commit', '-m', message, File.basename(CALENDAR),
          ['--no-auth-cache', '--non-interactive'],
          (['--username', $USER, '--password', $PASSWORD] if $PASSWORD)
        ]

        unless `svn st`.empty?
          _.system ['svn', 'status']
          raise "svn failure"
        end
      end
    end

    _h2 'Clean up board directory'
    Dir.chdir BOARD_PRIVATE do
      updated = false

      if File.exist? "board_minutes_#{date}.txt"
        _.system "svn rm board_minutes_#{date}.txt"
        updated = true
      end
      
      if File.exist? "board_agenda_#{date}.txt"
        _.system "svn mv board_agenda_#{date}.txt archived_agendas"
        updated = true
      end

      if updated
        _p
        _.system [
          'svn', 'commit', '-m', message,
          ['--no-auth-cache', '--non-interactive'],
          (['--username', $USER, '--password', $PASSWORD] if $PASSWORD)
        ]

        unless `svn st`.empty?
          _.system ['svn', 'status']
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

