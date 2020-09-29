#!/usr/bin/env ruby
PAGETITLE = "Incubator Mentor Signoffs" # Wvisible:incubator

# quick and dirty script to tally up which mentors have been providing
# signoffs and which have not.
$LOAD_PATH.unshift '/srv/whimsy/lib'
require 'nokogiri'
require 'wunderbar'
require 'wunderbar/bootstrap'
require 'whimsy/asf'

# Authenticate - must be first!
user = ASF::Person.find($USER)
incubator = ASF::Committee.find('incubator').owners
unless user.asf_member? or incubator.include? user
  print "Status: 401 Unauthorized\r\n"
  print "WWW-Authenticate: Basic realm=\"Incubator PMC and Members\"\r\n\r\n"
  exit
end

BOARD = ASF::SVN['foundation_board']
# Gather data from board agendas about podlings and actual mentors listed
def get_mentor_signoffs()
  ASF::Person.preload('cn')
  ASF::ICLA.preload()
  people = Hash[ASF::Person.list.map {|person| [person.public_name, person.id]}]

  agendas = Dir[File.join(BOARD, 'board_agenda_*.txt'),
    File.join(BOARD, 'archived_agendas', 'board_agenda_*.txt')]
  agendas = agendas.sort_by {|file| File.basename(file)}[-13..-1]
  if File.read(agendas.last).include? 'The Apache Incubator is the entry path'
    agendas.shift
  else
    agendas.pop
  end

  # projects = URI.parse('http://incubator.apache.org/projects/')
  # table = Nokogiri::HTML(Net::HTTP.get(projects)).at('table')
  # # extract a list of [podling names, table row]
  # podlings = table.search('tr').map do |tr|
  #   tds = tr.search('td')
  #   next if tds.empty?
  #   [tds.last.text, tr]
  # end

  mentors = {}
  podlings = {}
  agendas.each do |file|
    date = file[/\d+_\d+_\d+/].gsub('_', '-')
    agenda = File.read(file)
    signoffs = agenda.scan(/^#* ?Signed-off-by:\s+.*?\n\n/m).join
    signoffs.scan(/\[(.+?)\]\((.*?)\) (.*)/).each do |check, podling, name|
      name.strip!
      podling.strip!
      # allow for reports where comments have been joined to the previous line
      name.sub! %r{ Comments:.*}, ''
      name.sub! /\s+\(.*?\)/, ''

      mentors[name] = [] unless mentors[name]
      mentors[name] << {
        date: date,
        checked: !check.strip.empty?,
        podling: podling
      }

      podlings[podling] = Hash.new{|h,k| h[k] = [] } unless podlings[podling]
      podlings[podling][date] << [name, !check.strip.empty?]
    end
  end
  return mentors, podlings, people
end


mentor_signoffs, podling_signoffs, people = get_mentor_signoffs()
ROSTER_URL = '/roster/committer/'

_html do
  # http://bconnelly.net/2013/10/creating-colorblind-friendly-figures/
  _style %{
    .check {color: rgb(0,114,178)}
    .blank {color: rgb(230,159,0); font-style: italic; font-weight: bold}
  }
  _whimsy_body(
    title: PAGETITLE,
    related: {
      'https://incubator.apache.org/images/incubator_feather_egg_logo_sm.png' => 'Apache Incubator Egg Logo',
      'https://incubator.apache.org/projects/' => 'Incubator Podling List',
      '/incubator/moderators' => 'Incubator Mailing List Moderators',
      '#bypodling' => 'Signoffs By Podling'
    },
    helpblock: -> {
      _p do
        _ 'This script checks recent Incubator podling reports as submitted to the board agenda for mentor signoffs. '
        _span.check 'Blue'
        _ ' means signoff is present in that report, '
        _span.blank 'orange'
        _ ' means signoff is absent.'
        _br
        _a_ 'Signoffs By Mentor', href: '#bymentor'
        _ ' | '
        _a_ 'Signoffs By Podling', href: '#bypodling'
      end
    }
  ) do

    _whimsy_panel_table(
      title: "Podling Signoffs By Mentor",
      helpblock: -> {
        _p "This table shows all mentors and the podlings they signed off on. Hover over podling name to see date of report."
      }
    ) do
      _table.table.table_hover.table_striped id: 'bymentor' do
        _thead_ do
          _tr do
            _th 'Mentor Name'
            _th 'Podling Monthly Reports'
          end
        end
        _tbody do
          mentor_signoffs.sort.each do |name, entries|
            _tr_ do
              _td do
                if people[name]
                  if ASF::Person.find(people[name]).asf_member?
                    _b! {_a name, href: ROSTER_URL + people[name]}
                  else
                    _a name, href: ROSTER_URL + people[name]
                  end
                else
                  _a name, href: ROSTER_URL + "?" + URI.encode_www_form([["q", name]])
                end
              end

              _td do
                entries.each do |entry|
                  if entry[:checked]
                    _span.check entry[:podling], title: entry[:date]
                  else
                    _span.blank entry[:podling], title: entry[:date]
                  end
                end
              end
            end
          end
        end
      end
    end

    _whimsy_panel_table(
      title: "Podling Signoffs By Podling",
      helpblock: -> {
        _p "This table shows all podlings and how many mentors signed off on reports, by date.  Reminder: only checks recent monthly reports."
      }
    ) do
      _table.table.table_hover.table_striped id: 'bypodling' do
        _thead_ do
          _tr do
            _th 'Podling Name (signoff %)'
            _th 'Date: (Mentor signoffs/Number of mentors) ...'
          end
        end
        _tbody do
          podling_signoffs.sort.each do |podling, signoffs|
            m = 0
            s = 0
            signoffs.each do |month, mentors|
              m += mentors.length
              s += mentors.count { |x| x[1] }
            end
            _tr_ do
              _td do
                _a_ podling, href: "https://incubator.apache.org/projects/#{podling}"
                _ " (#{((s/m.to_f)*100).round()}%)"
              end
              _td do
                signoffs.each do |month, mentors|
                  _ " #{month} (#{mentors.count { |x| x[1] }} / #{mentors.length}) "
                end
              end
            end
          end
        end
      end
    end

  end
end
