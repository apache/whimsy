#!/usr/bin/ruby1.9.1

require 'wunderbar'
require '/var/tools/asf'

# mapping of committee names to canonical names (generally from ldap)
# See also asf/committee.rb
canonical = Hash.new {|hash, name| name}
canonical.merge! \
  'community development'       => 'comdev',
  'conference planning'         => 'concom',
  'conferences'                 => 'concom',
  'http server'                 => 'httpd',
  'httpserver'                  => 'httpd',
  'java community process'      => 'jcp',
  'lucene.net'                  => 'lucenenet',
  'quetzalcoatl'                => 'quetz',
  'security team'               => 'security',
  'open climate workbench'      => 'climate',
  'c++ standard library'        => 'stdcxx',
  'travel assistance'           => 'tac',
  'traffic server'              => 'trafficserver',
  'web services'                => 'ws',
  'xml graphics'                => 'xmlgraphics'

display_name = Hash.new {|hash, name| name}
namemap = Proc.new do |name|
  cname = canonical[name.downcase]
  display_name[cname] = name unless display_name.include? cname
  cname
end

# parse chairs and nonpmc names from committee-info.txt
board = ASF::SVN['private/committers/board']
committee = File.read("#{board}/committee-info.txt").split(/^\* /)
reporting = committee.first[/^2.(.*)\n3/m,1].scan(/^    (\w.*?)(?:\s*#|$)/).
  flatten.sort.map {|name| namemap.call(name)}.uniq
head = committee.shift.split(/^\d\./)[1]
chairs = Hash[head.scan(/^\s+(\w.*?)\s\s+.*<(\w+)@apache\.org>/).
  map {|name, id| [namemap.call(name), id]}]
nonpmcs = head.sub(/.*?also has/m,'').
  scan(/^\s+(\w.*?)\s\s+.*<\w+@apache\.org>/).flatten.uniq.map(&namemap)

# parse roster information and display names from committee-info.txt
info = {}
committee.each do |roster|
  roster.gsub! /^.*\(\s*emeritus\s*\).*/i, ''
  name =  roster[/(\w.*?)\s+\(/,1]
  info[namemap.call(name)] = roster.scan(/<(.*?)@apache\.org>/).flatten
end

# parse site information
site = {}
templates = ASF::SVN['asf/infrastructure/site/trunk/templates']
projects = File.read("#{templates}/blocks/projects.mdtext")
found = false
projects.scan(/\[(.*?)\]\((http.*?) "(.*)"\)/).each do |name, link, text|
  site[namemap.call(name)] = [link, text]
end

skeleton = File.read("#{templates}/skeleton.html")
projects = skeleton[/<h4>Foundation Projects<\/h4>(.*?)<h4>/m,1]
projects.scan(/<a href="(.*?)" title="(.*?)">(.*?)</).each do |link, text, name|
  cname =  namemap.call(name)
  link = 'http://www.apache.org' + link if link =~ /^\//
  nonpmcs << cname unless nonpmcs.include? cname
  site[cname] = [link, text]
end

committers = ASF.committers.map(&:id)

banned = ASF::Person.list('loginShell=/usr/bin/false').map(&:id)

_html do
  # extract pmc name from uri
  if ENV['REQUEST_URI'] =~ /committee\/(.+)/
    @pmc = CGI::unescape($1)
  end

  _head_ do
    if @pmc.to_s.empty?
      _title 'Apache Committees'
    else
      _title "Apache Committee - #{@pmc}"
    end
    _meta charset: 'utf-8'
    _style %{
      .issue {font-weight:bold; color: red}
      td:last-child {font-weight:bold}
      td:last-child:not(.chair) {color: red}
      td:last-child:not(:empty):before {content: '\u21d0 '}
      tr:hover {background-color: #FF8}
      td span {display: none}
      td:hover span {position: absolute; display: block; background-color: #FFF;
        padding: 1em; border: 2px solid #0F0; border-radius: 1em;
        color: black; font-weight: normal}
    }
  end

  _body? do
    # common banner
    _a href: 'https://whimsy.apache.org/' do
      _img title: "ASF Logo", alt: "ASF Logo", 
        src: "https://id.apache.org/img/asf_logo_wide.png"
    end

    if @pmc
      # individual pmc display page
      @pmc.untaint if @pmc =~ /^[-\w]+$/
      name = canonical[@pmc.downcase]

      # extract roster from committee-info.txt
      info = (info[name] || []).map {|uid| ASF::Person.find(uid)}

      # extract roster from ldap
      if name.tainted?
        committee = []
        group = []
      else
        committee = ASF::Committee.find(name).members
        group = ASF::Group.find(name).members
      end

      # merge the two sources
      pmc = (info + committee).uniq

      if name == 'orphans'
        pmc = ASF::Person.list - 
         ASF::Group.list.map(&:members).flatten - 
         ASF::Committee.list.map(&:members).flatten - 
         ASF.members
      end

      # header for pmc, and pmc wide notices
      if site.include? name
        # site information found, link to it
        link, text = site[name]
        _h1_ do
          _a display_name[name], href: link, title: text
        end
        if pmc.empty?
          _p 'Project not found, but is in the navigation ' +
            'list of projects on apache.org', class: 'issue'
        elsif info.empty?
          _p 'Not in committee-info.txt', class: 'issue'
        elsif committee.empty?
          if nonpmcs.include? name
            _p 'Not in ldap'
          else
            _p 'Not in ldap', class: 'issue'
          end
        elsif not reporting.include? name
          _p 'Not in reporting schedule', class: 'issue'
        end
      else
        # site information not found
        _h1_ display_name[name]
        if name == 'orphans'
        elsif pmc.empty?
          _p 'Project not found', class: 'issue'
        else
          if not nonpmcs.include? name
            _p 'Not in the navigation list of projects on apache.org',
              class: 'issue'
          end
          if committee.empty?
            _p 'Not in LDAP', class: 'issue'
          end
          if info.empty?
            _p 'Not in committee-info.txt', class: 'issue'
          end
          if not reporting.include? name
            _p 'Not in reporting schedule', class: 'issue'
          end
        end
      end

      if (group - pmc).empty?
        unless pmc.empty?
          _h2_ 'PMC==Committers'
        end
      else
        _h2_ 'PMC'
      end

      # prevent complaining if the person is banned
      recognized = committers + banned

      _table_ do
	pmc.sort_by {|person| person.id}.each do |person|
	  _tr_ do
            # availid
	    _td do
	      _a person.id, href: "../committer/#{person.id}"
	    end

            # display name
            if not person.asf_member?
	      _td person.public_name
            elsif person.asf_member? == true
	      _td { _strong person.public_name }
            else
	      _td { _em person.public_name }
            end

            # notices
	    if not committee.include?(person) and not committee.empty?
	      _td do
                _indented_text! 'not in LDAP committee'
                _span "modify_committee.pl #{name} --add #{person.id}"
              end
	    elsif not group.include?(person) and not group.empty?
	      _td do
                _indented_text! 'not in LDAP group'
                _span "modify_unix_group.pl #{name} --add #{person.id}"
              end
	    elsif not info.empty? and not info.include? person
	      _td do
                _indented_text! 'not in committee-info.txt'
                _span "modify_committee.pl #{name} --rm #{person.id}"
              end
            elsif not recognized.include? person.id
              _td do
                if name == 'orphans'
                  _indented_text! 'Not disabled'
                else
                  _indented_text! 'Not in ASF list of committers'
		  if person.public_name
                    _span "modify_unix_group.pl committers --add #{person.id}"
		  else
                    _span "modify_unix_group.pl #{name} --rm #{person.id}"
		  end
		end
              end
	    elsif not person.icla
	      _td do
                _indented_text! 'missing ICLA'
                _span "modify_unix_group.pl #{name} --rm #{person.id}"
	      end
	    elsif chairs[name] == person.id
	      _td 'chair', class: 'chair'
            else
	      _td
	    end
	  end
	end
      end

      unless (group - pmc).empty?
        _h2_ 'Committers (excluding PMC members already listed above)'
        _table_ do
	  group.sort_by {|person| person.id}.each do |person|
            next if pmc.include? person
	    _tr_ do
              # availid
	      _td do
	        _a person.id, href: "../committer/#{person.id}"
	      end

              if not person.asf_member?
	        _td person.public_name
              elsif person.asf_member? == true
	        _td { _strong person.public_name }
              else
	        _td { _em person.public_name }
              end

              if not recognized.include? person.name
                _td do
		  _indented_text! 'Not in ASF list of committers'
		  if person.public_name
                    _span "modify_unix_group.pl committers --add #{person.id}"
		  else
                    _span "modify_unix_group.pl #{name} --rm #{person.id}"
		  end
		end
              elsif person.public_name
                _td
              else
                _td do
		  _indented_text! 'Missing ICLA'
                  _span "modify_unix_group.pl #{name} --rm #{person.id}"
		end
              end
            end
          end
        end
      end

      # links
      _ul do
        _li do
	  _a 'How to grant SVN access to a project source repository',
	    href: 'http://www.apache.org/dev/pmc.html#SVNaccess'
	end
        _li do
	  _a 'infrastructure site README',
	    href: 'http://svn.apache.org/repos/asf/infrastructure/site/trunk/README'
	end
        _li do
	  _a 'committee-info.txt',
	    href: 'https://svn.apache.org/repos/private/committers/board/committee-info.txt'
	end
      end

    else # PMC list

      # TODO remove? appears to be overwritten before first use
      pmcs = ASF::Committee.list

      # get a list of chairs from LDAP
      ldap_chairs = ASF.pmc_chairs

      # membership of each PMC
      pmc_members = Hash[
        ASF.search_one(ASF::Committee.base, 'cn=*', %w(cn member)).
          map {|attrs| [ attrs['cn'].first, 
            (attrs['member'] || []).map {|uid| uid[/uid=(.*?),/,1]} ] }
      ]

      # membership of each group
      groups = Hash[
        ASF.search_one(ASF::Group.base, 'cn=*', %w(cn memberUid)).
          map {|attrs| [ attrs['cn'].first, attrs['memberUid'] || [] ] }
      ]

      # list of pmcs from ldap 
      pmcs = pmc_members.keys

      # list of people with an ICLA
      iclas = Hash[ASF::ICLA.new.each.map {|id, name, email| [id, 1]}]

      # table has two sections, first a list of pmcs then other committees
      pmcsection = true
      _h1_ "PMCs"

      # merge names from committee-info.txt, ldap and site, eliminating nonpmcs
      names = (info.keys + pmcs + site.keys + reporting + chairs.keys).
        uniq.compact

      _table_ do
        ((names-nonpmcs).sort + nonpmcs.sort).each do |name|

          # this is admittedly kind-of a hack, but when encountering the
          # first non-pmc, dump a list of ldap-chairs that are not currently
          # chairs, then insert a header in the middle of the table
          if pmcsection and nonpmcs.include? name
            ldap_chairs.sort_by {|p| p.name}.each do |chair|
              next if chairs.values.include? chair.name
              _tr_ do
	        _td { _em 'missing' }
                if chair.asf_member?
                  _td do
                    _strong chair.public_name, title: chair.name
                  end
                else
                  _td chair.public_name, title: chair.name
                end
	        _td 'pmc-chair not listed in committee-info.txt'
	      end
            end

            _tr_ do
              _td colspan: '3' do
                _h1 "Other Offices and Committees", id: 'other'
              end
              _td
            end
            pmcsection = false
          end

          # extract committee roster from ldap
          pmc_names = (pmc_members[name] || []).sort

          _tr_ do
            # committtee name, linking to page if there is a roster to be found
            if not pmc_names.empty? or info.include? name
              _td do
                _a display_name[name], href: name
              end
            elsif site.include? name
              # site information found, link to it
              link, text = site[name]
              _td do
                _a display_name[name], href: link
              end
            else
              _td display_name[name]
            end

            # chair name, bold if the chair is an ASF member
            chair = ASF::Person.find(chairs[name])
            if chair.asf_member?
              _td do
                _strong chair.public_name
              end
            elsif chair
              _td chair.public_name
            else
	      _td { _em 'missing' }
            end

            # notices
            if chair and not reporting.include? name
              _td 'not in reporting schedule'
            elsif not info[name] or info[name].empty?
              if not pmc_names.empty?
                _td 'ldap only'
              elsif chair.icla and nonpmcs.include? name
                _td 'chair only', class: 'chair'
              elsif site.include? name
                _td 'website only'
              elsif chair
                _td 'chair only'
              elsif reporting.include?  name
                _td 'only in reporting schedule'
              else
                _td 'not found'
              end
            elsif pmc_names.empty?
              if nonpmcs.include? name
                _td
              else
                _td 'committee-info.txt only'
              end
            elsif info[name].sort == pmc_names
              if pmc_names.any? {|id| not iclas.include? id}
                if pmc_names.one? {|id| not iclas.include? id}
                  _td 'missing an ICLA on file'
                else
                  _td 'missing ICLAs on file'
                end
              elsif not site.include? name
                _td 'not linked in sidebar on apache.org web site'
              elsif not pmc_names.include? chairs[name]
                if nonpmcs.include? name
                  _td
                else
                  _td 'chair not in pmc-chairs ldap group'
                end
              elsif not groups[name]
                if nonpmcs.include? name
                  _td
                else
                  _td 'no corresponding LDAP group'
                end
              elsif not (pmc_members[name] - groups[name]).empty?
                if (pmc_members[name] - groups[name]).length == 1
                  _td 'one committee member not in LDAP group'
                else
                  _td 'multiple committee members not in LDAP group'
	        end
              elsif not (groups[name] - committers - banned).empty?
	        if (groups[name] - committers - banned).length > 1
                  _td 'multiple group members not in list of committers'
	        else
                  _td 'one group member not in list of committers'
		end
              else
                _td
              end
            elsif (info[name] - pmc_names).empty?
              if (pmc_names - info[name]).length == 1
                _td 'ldap contains an additional entry'
              else
                _td 'ldap contains additional entries'
              end
            elsif (pmc_names - info[name]).empty?
              if (info[name] - pmc_names).length == 1
                _td 'committee-info.text contains an additional entry'
              else
                _td 'committee-info.text contains additional entries'
	      end
            else
              _td 'multiple differences found'
            end
          end

        end
      end
    end

  end
end
