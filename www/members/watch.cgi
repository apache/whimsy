#!/usr/bin/ruby1.9.1
require 'wunderbar'
require '/var/tools/asf'
require 'nokogiri'
require 'date'

SVN_BOARD = "https://svn.apache.org/repos/private/foundation/board"
meetings = ASF::SVN['private/foundation/Meetings']

_html do
  _head_ do
    _title 'Potential Member Watch'
    _style %{
      th {border-bottom: solid black}
      table {border-spacing: 1em 0.2em }
      tr td:first-child {text-align: center}
      .issue {color: red; font-weight: bold}
      .header span {float: right}
      .header span:after {padding-left: 0.5em}
      .headerSortUp span:after {content: " \u2198"}
      .headerSortDown span:after {content: " \u2197"}
    }
    _script src: '/jquery.min.js'
    _script src: '/jquery.tablesorter.js'
  end

  _body? do
    # common banner
    _a href: 'https://id.apache.org/' do
      _img title: "Logo", alt: "Logo",
        src: "https://id.apache.org/img/asf_logo_wide.png"
    end

    # start with the Watch List itself
    watch_list = ASF::Person.member_watch_list.keys

    nominations = File.read("#{meetings}/20120522/nominated-members.txt").
      scan(/^\s?\w+.*<(\S+)@apache.org>/).flatten
    nominations += File.read("#{meetings}/20120522/nominated-members.txt").
      scan(/^\s?\w+.*\(([a-z]+)\)/).flatten

    # determine which list to report on, based on the URI
    request = ENV['REQUEST_URI']
    if request =~ /multiple/
      _h2_ 'Active In Multiple Committees'
      list = ASF::Committee.list.map {|committee| committee.members}.
        reduce(&:+).group_by {|person| person}.
        delete_if {|person,list| list.length<3}.keys
      list -= ASF.members
    elsif request =~ /chairs/
      _h2_ 'PMC Chairs'
      list = ASF.pmc_chairs
      list -= ASF.members
    elsif request =~ /nominees/
      _h2_ 'Nominees'
      list = nominations.uniq.map {|id| ASF::Person.find(id)}
    elsif request =~ /appstatus/
      _h2_ 'Application Status'
      status = File.read("#{meetings}/20120522/memapp-received.txt").
        scan(/^(yes|no)\s+(yes|no)\s+(yes|no)\s+(yes|no)\s+(\w+)\s/)
      status = Hash[status.map {|tokens| [tokens.pop, tokens]}]
      list = status.keys.map {|id| ASF::Person.find(id)}
    else
      _h2_ 'Watch List'
      list = watch_list
    end

    # for efficiency, preload public_names
    ASF::Person.preload('cn', list)

    _table do

      _thead_ do
        _tr do
          if request =~ /appstatus/
            _th 'Invited?'
            _th 'Applied?'
            _th 'members@?'
            _th 'Karma'
          elsif request =~ /nominees/
            _th 'Seconded?'
          else
            _th 'Nominated?'
	  end
          
          _th 'AvailID'
          _th 'Name'

          if request !~ /appstatus/
          _th 'Committees'
          _th 'Chair Since'
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
                _td.issue cols[0]
	      end

              _td cols[1]

	      if cols[1] == 'no' or cols[2] == 'yes'
                _td cols[2]
              else
                _td.issue cols[2]
              end

	      if cols[1] == 'no' or cols[3] == 'yes'
                _td cols[3]
              else
                _td.issue cols[3]
              end
            elsif request =~ /nominees/
              if person.member_nomination =~ /Seconded by: \w/
                _td 'yes'
              else
                _td.issue 'no'
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
                _strong {_a person.id, href: "/roster/committer/#{person.id}"}
              end
            else
              _td! {_a person.id, href: "/roster/committer/#{person.id}"}
            end

            # public name
            _td person.public_name
  

            if request !~ /appstatus/
	      # committees
	      _td do
		person.committees.sort_by(&:name).each do |committee|
		  if committee.chair == person
		    _strong do
		      _a committee.name, href: "/roster/committee/#{committee.name}"
		    end
		  else
		    _a committee.name, href: "/roster/committee/#{committee.name}"
		  end
		end
	      end
    
	      # chair since
	      chair = person.committees.find {|committee| committee.chair == person}
	      if chair
		minutes = Dir['/var/www/board/minutes/*'].find do |name|
		  File.basename(name).split('.').first.downcase.gsub(/[_\W]/,'') ==
		    "#{chair.name.gsub(/\W/,'')}"
		end
    
		search_string = "RESOLVED, that #{person.public_name}"
		search_string.force_encoding('utf-8')

		# search published minutes
		resolution = nil
		minutes.untaint
		Nokogiri::HTML(File.read(minutes)).search('pre').each do |pre|
		  if pre.text.include? search_string
		    resolution = pre
		    while resolution and resolution.name != 'h2'
		      resolution = resolution.previous
		    end
		    break if resolution
		  end
		end
    
		date = 'unknown'
		minutes = '/board/minutes/' + File.basename(minutes)
		if resolution
		  minutes += '#' + resolution.at('a')['id']
		  date = Date.parse(resolution.text)
		else
		  # search unpublished agendas
		  board = ASF::SVN['private/foundation/board']
		  Dir["#{board}/board_agenda_*"].sort.each do |agenda|
		    agenda.untaint
		    if File.read(agenda).include? search_string
		      minutes = "#{SVN_BOARD}/#{File.basename(agenda)}"
		      date = agenda.gsub('_','-')[/(\d+-\d+-\d+)/,1]
		      break
		    end
		  end
		end

		_td do
		  _a date, href: minutes
		end
              end
            end
          end
        end
      end
    end

    _h2_ 'Related Links'
    _ul do
      unless request =~ /appstatus/
        _li do
          _a 'Application Status', href: '/members/watch/nominees'
        end
      end
      unless list == watch_list
        _li do
          _a 'Potential Member Watch List', href: '/members/watch'
        end
      end
      unless request =~ /nominees/
        _li do
          _a 'Nominees', href: '/members/watch/nominees'
        end
      end
      unless request =~ /multiple/
        _li do
          _a 'Active in Multiple (>=3) PMCs', href: '/members/watch/multiple'
        end
      end
      unless request =~ /chairs/
        _li do
          _a 'Non-member PMC chairs', href: '/members/watch/chairs'
        end
      end
    end

    _script %{
      var numheaders = $('thead th').length;
      $('table').tablesorter({sortList: [[numheaders-1,0]]});
      $('.header').append('<span></span>');
    }
  end
end
