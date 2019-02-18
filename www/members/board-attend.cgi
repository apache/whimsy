#!/usr/bin/env ruby
PAGETITLE = "Board Meeting Attendance since 2010" # Wvisible:meeting
$LOAD_PATH.unshift '/srv/whimsy/lib'

require 'whimsy/asf'
require 'whimsy/asf/agenda'
require 'whimsy/public'
require 'wunderbar/bootstrap'
require 'json'
require 'set'

BOARD = ASF::SVN['foundation_board']
IS_DIRECTOR = :director
APPROVED = 'approved'

# Map director ids->names and ids->initials
# Only since 2010, once the preapp data in meetings is parseable
INITIALS = 0
FIRST_NAME = 1
DISPLAY_NAME = 2
DIRECTOR_MAP = {
  'bdelacretaz' => ['bd', 'Bertrand', 'Bertrand Delacretaz'],
  'brett' => ['bp', 'Brett', 'Brett Porter'],
  'brianm' => ['bmc', 'Brian', 'Brian McCallister'],
  'curcuru' => ['sc', 'Shane', 'Shane Curcuru'],
  'cutting' => ['dc', 'Doug', 'Doug Cutting'],
  'dkulp' => ['dk', 'Daniel', 'Daniel Kulp'],
  'fielding' => ['rf', 'Roy', 'Roy T. Fielding'],
  'geirm' => ['gmj', 'Geir', 'Geir Magnusson Jr'],
  'gstein' => ['gs', 'Greg', 'Greg Stein'],
  'isabel' => ['idf', 'Isabel', 'Isabel Drost-Fromm'],
  'jerenkrantz' => ['je', 'Justin', 'Justin Erenkrantz'],
  'jim' => ['jj', 'Jim', 'Jim Jagielski'],
  'ke4qqq' => ['dn', 'David', 'David Nalley'],
  'lrosen' => ['lr', 'Larry', 'Lawrence Rosen'],
  'markt' => ['mt', 'Mark', 'Mark Thomas'],
  'marvin' => ['mh', 'Marvin', 'Marvin Humphrey'],
  'mattmann' => ['cm', 'Chris', 'Chris Mattmann'],
  'noirin' => ['np', 'Noirin', 'Noirin Plunkett'],
  'psteitz' => ['ps', 'Phil', 'Phil Steitz'],
  'rbowen' => ['rb', 'Rich', 'Rich Bowen'],
  'rgardler' => ['rg', 'Ross', 'Ross Gardler'],
  'rubys' => ['sr', 'Sam', 'Sam Ruby'],
  'rvs' => ['rs', 'Roman', 'Roman Shaposhnik'],
  'tdunning' => ['td', 'Ted', 'Ted Dunning']
}

# Summarize director attendance and preapps at one meeting into dstats
# @note that ASF::Board::Agenda has mix of symbols and strings for hash keys
# @return string if error
# Side effect: fills in dstats
#   Each director gets one entry for each meeting they were a director
def summarize(fname, dstats)
  meeting = File.basename(fname, '.*')
  begin
    agenda = ASF::Board::Agenda.parse(File.read(fname.untaint))
  rescue StandardError => e
    return "summarize(#{fname}) Agenda parse error: #{e.message} #{e.backtrace[0]}"
  end
  begin
    people = agenda[1]['people']
  rescue StandardError => e
    return "summarize(#{fname}) no attendance error: #{e.message} #{e.backtrace[0]}"
  end
  begin
    people.each do |id, att|
      if IS_DIRECTOR.eql?(att[:role])
        dstats[id][meeting] = {'present' => att[:attending]}
      end
    end
    reports = agenda.select{ |v| v.has_key?(APPROVED) && ! v.has_key?('missing') }
    numreports = reports.length.to_f
    actions = agenda.select{ |v| v.has_key?(:index) && v[:index] == "Action Items" }[0]['actions']
    dstats.each do |id, dirmtg|
      if dirmtg.has_key?(meeting)
        dirmtg[meeting]['preapps'] = (reports.select {|v| v[APPROVED].include?(DIRECTOR_MAP[id][INITIALS])}.length / numreports).round(3)
        dirmtg[meeting]['actions'] = actions.select{ |v| v[:owner] == DIRECTOR_MAP[id][FIRST_NAME] }.length
      end
    end
  rescue StandardError => e
    return "summarize(#{fname}) process error: #{e.message} #{e.backtrace[0]}"
  end
  return nil
end

# Create summary of director attendance from board minutes (includes private data)
# Note that prior to Dec 2012 and for F2F meetings, this won't parse
# @param dir pointing to /foundation/board/archived_agendas
# @return stats hash of each director's attendance & etc., error array
def summarize_all(dir = BOARD)
  summaries = Hash.new{|h,k| h[k] = {} }
  errors = []
  Dir[File.join(dir, 'archived_agendas', "board_agenda_201*.txt")].each do |f|
    e = summarize(f, summaries)
    errors << e if e
  end
  return summaries, errors
end

# If JSON requested, simply return the data hash
_json do
  summaries, errors = summarize_all
  summaries
end

# produce HTML
_html do
  _whimsy_body(
    title: PAGETITLE,
    related: {
      '/board/minutes' => 'Monthly Board Meeting Minutes (categorized)',
      'https://www.apache.org/foundation/board/calendar.html' => 'Monthly Board Meeting Minutes (by date)',
      '/roster/group/board' => 'Current List of Directors'
    },
    helpblock: -> {
      _ 'This lists statistics about director attendance and report preapprovals at monthly board meetings since 2013.  Before 2013, the preapproval data isn\'t easily parseable.'
    }
  ) do
    datums = JSON.parse(File.read(File.join(BOARD, 'scripts', 'board-attend.json')))
    months = Set.new()
    datums.each do |id, data|
      data.keys.each do |m|
        months << m
      end
    end
    _whimsy_panel_table(
      title: "Director attendance at monthly board meetings",
      helpblock: -> {
        _p do 
          _ "Includes data from #{months.min} to #{months.max} regularly scheduled monthly board meetings.  Key:"
          _ul do
            _li 'Mtgs Attended - # of meetings attended when they were a director'
            _li 'Mtgs Missed - # of meetings missed when they were a director'
            _li.text_muted '% Reports Preapp - average %age of reports they pre-approved in Whimsy (member-private)'
            _li 'Avg Action Items - average number of Action Items assigned per month'
          end
        end
      }
    ) do
      _table.table.table_hover.table_striped do
        _thead_ do
          _tr do
            _th 'Director'
            _th 'Mtgs Attended'
            _th 'Mtgs Missed'
            _th do
              _span.text_muted '% Reports Preapp'
            end
            _th 'Avg Action Items'
          end
          _tbody do
            datums.each do | id, data |
              totp = 0.0
              tota = 0.0
              data.each do |k,v|
                totp += v['preapps']
                tota += v['actions']
              end
              _tr_ do
                _td do
                  if DIRECTOR_MAP[id] and DIRECTOR_MAP[id][DISPLAY_NAME]
                    _ DIRECTOR_MAP[id][DISPLAY_NAME]
                  else
                    _em.bg_danger id
                  end
                end
                _td do
                  _ data.select{|k,v| v['present']}.length
                end
                _td do
                  _ data.select{|k,v| !v['present']}.length
                end
                _td do
                  _span.text_muted "#{((totp / data.length)*100).round(0)}%"
                end
                _td do
                  _ (tota / data.length).round(2)
                end
              end
            end
          end
        end
      end
    end
  end
end
