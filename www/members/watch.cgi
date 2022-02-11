#!/usr/bin/env ruby
PAGETITLE = "Potential ASF Member Watch List" # Wvisible:members
$LOAD_PATH.unshift '/srv/whimsy/lib'

require 'wunderbar'
require 'whimsy/asf'
require 'whimsy/asf/member-files'
require 'nokogiri'
require 'date'
require 'wunderbar/bootstrap'
require 'wunderbar/jquery/stupidtable'

_html do
  _head_ do
    _base href: File.dirname(ENV['SCRIPT_NAME'])
  end

  _body? do
    _whimsy_body(
      title: PAGETITLE,
      related: {
        '/members/memberless-pmcs' => 'PMCs with no/few ASF Members',
        '/members/nominations' => 'Members Meeting Nomination Crosscheck',
        ASF::SVN.svnpath!('Meetings') => 'Official Meeting Agenda Directory'
      },
      helpblock: -> {
        _ 'To help evaluate potential Member candidates, here are a number of ways to see where non-Members are participating broadly at the ASF.'
        _ 'The table(s) below include non-Members who are chairs, widely active, have been nominated, or other criteria (depending on this URL).'
      }
    ) do
      # start with the Watch List itself
      watch_list = ASF::Person.member_watch_list.keys
      meeting = ASF::MemberFiles.latest_meeting

      nominations = ASF::MemberFiles.member_nominees.map {|k, _v| k}

      # determine which list to report on, based on the URI
      request = ENV['REQUEST_URI']

      _div.row do
        _div.col_sm10 do
          _div.panel.panel_primary do
            _div.panel_heading {_h3.panel_title 'Related Links'}
            _div.panel_body do
              _ul do
                if Time.new.strftime('%Y%m%d') < File.basename(meeting)
                  _li do
                    _a 'Posted nominations vs svn', href: 'members/nominations'
                  end
                else
                  unless request =~ /appstatus/
                    _li do
                      _a 'Application Status', href: 'members/watch/appstatus'
                    end
                  end
                end

                _li do
                  _a 'Potential Member Watch List', href: 'members/watch'
                end

                unless request =~ /nominees/
                  _li do
                    _a 'Nominees', href: 'members/watch/nominees'
                  end
                end

                unless request =~ /multiple/
                  _li do
                    _a 'Active in Multiple (>=3) PMCs', href: 'members/watch/multiple'
                  end
                end

                unless request =~ /chairs/
                  _li do
                    _a 'Non-member PMC chairs', href: 'members/watch/chairs'
                  end
                end

                unless request =~ /mentors/
                  _li do
                    _a 'Non-member incubator mentors', href: 'members/watch/mentors'
                  end
                end

                _li do
                  _a 'PMCs with no/few members', href: 'members/memberless-pmcs'
                end
              end
            end
          end
        end
      end

      list = {} # Avoid lint errors of shadowing
      if request =~ /multiple/
        _h2_ 'Active In Multiple Committees'
        # Use actual PMCs rather than LDAP derived
        list = ASF::Committee.pmcs.map {|pmc| pmc.roster.keys}.
          reduce(&:+).group_by {|uid| uid}.
          delete_if {|_, lst| lst.length < 3}.
          map {|uid, _| ASF::Person.find(uid)}
        list -= ASF.members
      elsif request =~ /chairs/
        _h2_ 'PMC Chairs'
        list = ASF.pmc_chairs
        list -= ASF.members
      elsif request =~ /mentors/
        _h2_ 'Incubator Mentors'
        list = ASF::Podling.current.map(&:mentors).flatten.
          uniq.map {|id| ASF::Person.find(id)}
        list -= ASF.members
      elsif request =~ /nominees/
        _h2_ 'Member Nominees'
        list = nominations.uniq.map {|id| ASF::Person.find(id)}
      elsif request =~ /appstatus/
        _h2_ 'Elected Members - Application Status'
        status = File.read(File.join(meeting, 'memapp-received.txt')).
          scan(/^(yes|no)\s+(yes|no)\s+(yes|no)\s+(yes|no)\s+(\w+)\s/)
        status = status.map {|tokens| [tokens.pop, tokens]}.to_h
        list = status.keys.map {|id| ASF::Person.find(id)}
      else
        _h2_ 'From potential-member-watch-list.txt'
        list = watch_list
      end

      _table.table do

        _thead_ do
          _tr do
            if request =~ /appstatus/
              _th 'Invited?', data_sort: 'string'
              _th 'Applied?', data_sort: 'string'
              _th 'members@?', data_sort: 'string'
              _th 'Karma', data_sort: 'string'
            elsif request =~ /nominees/
              _th 'Seconded?'
            else
              _th 'Nominated?'
            end

            _th 'AvailID', data_sort: 'string'
            _th 'Name', data_sort: 'string'

            if request !~ /appstatus/
            _th 'Committees', data_sort: 'string'
            _th 'Chair Since', data_sort: 'string'
            end
          end
        end

        _tbody do
          list.sort_by {|id| id.public_name.to_s}.each do |person|

            _tr_ do

              if request =~ /appstatus/
                cols = status[person.id]

                if cols[0] == 'yes'
                  _td cols[0]
                else
                  _td.text_danger cols[0]
                end

                if cols[0] == 'no' or cols[1] == 'yes'
                  _td cols[1]
                else
                  _td.text_danger cols[1]
                end

                if cols[1] == 'no' or cols[2] == 'yes'
                  _td cols[2]
                else
                  _td.text_danger cols[2]
                end

                if cols[3] == 'yes'
                  _td cols[3], class: ('issue' unless person.asf_member?)
                elsif cols[1] == 'no'
                  _td cols[3], class: ('issue' if person.asf_member?)
                else
                  _td.text_danger cols[3]
                end
              elsif request =~ /nominees/
                if person.member_nomination =~ /Seconded by: \w/
                  _td 'yes'
                else
                  _td.text_danger 'no'
                end
              else
                if nominations.include? person.id
                  _td 'yes'
                else
                  _td
                end
              end

              # ASF id
              if person.id =~ /^notinavail_\d+$/
                _td
              elsif person.asf_member?
                _td! do
                  _strong {_a person.id, href: "roster/committer/#{person.id}"}
                end
              else
                _td! {_a person.id, href: "roster/committer/#{person.id}"}
              end

              # public name
              _td person.public_name


              if request !~ /appstatus/
                # committees
                _td do
                  person.committees.sort_by(&:name).each do |committee|
                    if committee.chair == person
                      _strong do
                        _a committee.name, href: "roster/committee/#{committee.name}"
                      end
                    else
                      _a committee.name, href: "roster/committee/#{committee.name}"
                    end
                  end
                end

                # chair since
                chair = person.committees.find {|committee| committee.chair == person}
                if chair
                  minutes = Dir['../board/minutes/*'].find do |name|
                    File.basename(name).split('.').first.downcase.gsub(/[_\W]/,'') ==
                      chair.name.gsub(/\W/,'')
                  end

                  search_string = "RESOLVED, that #{person.public_name}"
                  search_string.force_encoding('utf-8')

                  # search published minutes
                  if minutes
                    resolution = nil
                    Nokogiri::HTML(File.read(minutes)).search('pre').each do |pre|
                      if pre.text.include? search_string
                        resolution = pre
                        while resolution and resolution.name != 'h2'
                          resolution = resolution.previous
                        end
                        break if resolution
                      end
                    end
                  end

                  date = 'unknown'
                  if minutes
                    minutes = 'board/minutes/' + File.basename(minutes)
                  end
                  if resolution
                    minutes += '#' + resolution.at('a')['id']
                    date = Date.parse(resolution.text)
                  else
                    # search unpublished agendas
                    board = ASF::SVN['foundation_board']
                    Dir[File.join(board, 'board_agenda_*')].sort.each do |agenda|
                      if File.read(agenda).include? search_string
                        minutes = ASF::SVN.svnpath!('foundation_board', File.basename(agenda))
                        date = agenda.gsub('_','-')[/(\d+-\d+-\d+)/,1]
                        break
                      end
                    end
                  end

                  _td do
                    _a date, href: minutes
                  end
                else
                  _td '-'
                end
              end
            end
          end
        end
      end

      _script %{
        var table = $(".table").stupidtable();
        table.on("aftertablesort", function (event, data) {
          var th = $(this).find("th");
          th.find(".arrow").remove();
          var dir = $.fn.stupidtable.dir;
          var arrow = data.direction === dir.ASC ? "&uarr;" : "&darr;";
          th.eq(data.column).append('<span class="arrow">' + arrow +'</span>');
          });
        }
    end
  end
end
