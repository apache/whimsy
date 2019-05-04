##   Licensed to the Apache Software Foundation (ASF) under one or more
##   contributor license agreements.  See the NOTICE file distributed with
##   this work for additional information regarding copyright ownership.
##   The ASF licenses this file to You under the Apache License, Version 2.0
##   (the "License"); you may not use this file except in compliance with
##   the License.  You may obtain a copy of the License at
## 
##       http://www.apache.org/licenses/LICENSE-2.0
## 
##   Unless required by applicable law or agreed to in writing, software
##   distributed under the License is distributed on an "AS IS" BASIS,
##   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
##   See the License for the specific language governing permissions and
##   limitations under the License.

require 'time'

module ASF

  # Define super class to prevent circular references.  This class is
  # actually defined in ldap.rb which is require'd after committee.rb.
  class Base # :nodoc:
  end

  #
  # Representation for a committee (either a PMC, a board committee, or
  # a President's committee).  This data is parsed from 
  # <tt>committee-info.txt</tt>, and is augmened by data from LDAP,
  # ASF::Site, and ASF::Mail.
  #
  # Note that the simple attributes which are sourced from
  # <tt>committee-info.txt</tt> data is generally not available until
  # ASF::Committee.load_committee_info is called.
  #
  # Similarly, the simple attributes which are sourced from LDAP is
  # generally not available until ASF::Project.preload is called.

  class Committee < Base
    # list of chairs for this committee.  Returned as a list of hashes
    # containing the <tt>:name</tt> and <tt>:id</tt>.  Data is obtained from
    # <tt>committee-info.txt</tt>.
    attr_accessor :chairs

    # list of members for this committee.  Returned as a list of ids.
    # Data is obtained from <tt>committee-info.txt</tt>.
    attr_reader :info

    # when this committee is next expected to report.  May be a string
    # containing values such as "Next month: missing in May", "Next month: new,
    # montly through July".  Data is obtained from <tt>committee-info.txt</tt>.
    attr_writer :report

    # list of members for this committee.  Returned as a list of hash
    # mapping ids to a hash of <tt>:name</tt> and <tt>:date</tt> values. 
    # Data is obtained from <tt>committee-info.txt</tt>.
    attr_accessor :roster

    # Date this committee was established in the format MM/YYYY.
    # Data is obtained from <tt>committee-info.txt</tt>.
    attr_accessor :established

    # list of months when his committee typically  reports.  Returned
    # as a comma separated string.  Data is obtained from
    # <tt>committee-info.txt</tt>.
    attr_accessor :schedule

    # create an empty committee instance
    def initialize(*args)
      @info = []
      @chairs = []
      @roster = {}
      super
    end

    # mapping of committee names to canonical names (generally from ldap)
    # See also www/roster/committee.cgi
    @@aliases = Hash.new {|hash, name| name.downcase}
    @@aliases.merge! \
      'community development'       => 'comdev',
      # TODO: are the concom entries correct? See INFRA-17782
      'conference planning'         => 'concom',
      'conferences'                 => 'concom',
      'distributed release audit tool'=> 'drat',
      'http server'                 => 'httpd',
      'httpserver'                  => 'httpd',
      'java community process'      => 'jcp',
      'logging services'            => 'logging',
      'lucene.net'                  => 'lucenenet',
      'portable runtime'            => 'apr',
      'quetzalcoatl'                => 'quetz',
      'security team'               => 'security',
      'open climate workbench'      => 'climate',
      'c++ standard library'        => 'stdcxx',
      'travel assistance'           => 'tac',
      'web services'                => 'ws',
      'incubating'                  => 'incubator' # special for index.html

    @@namemap = Proc.new do |name|
      # Drop parenthesized comments and downcase before lookup; drop all spaces after lookup
      # So aliases table does not need to contain entries for Traffic Server and XML Graphics.
      # Also compress white-space before lookup so tabs etc from index.html don't matter
      cname = @@aliases[name.sub(/\s+\(.*?\)/, '').strip.gsub(/\s+/, ' ').downcase].gsub(/\s+/, '')
      cname
    end

    # load committee info from <tt>committee-info.txt</tt>.  Will not reparse
    # if the file has already been parsed and the underlying file has not
    # changed.
    def self.load_committee_info(contents = nil, info = nil)
      if contents
        if info
          @committee_mtime = @@svn_change =
            Time.parse(info[/Last Changed Date: (.*) \(/, 1]).gmtime
        else
          @committee_mtime = @@svn_change = Time.now
        end

        parse_committee_info contents
      else
        board = ASF::SVN.find('board')
        return unless board
        file = File.join(board, 'committee-info.txt')
        return unless File.exist? file

        if @committee_mtime and File.mtime(file) <= @committee_mtime
          return @committee_info  if @committee_info
        end

        @committee_mtime = File.mtime(file)
        @@svn_change = Time.parse(
          `svn info #{file}`[/Last Changed Date: (.*) \(/, 1]).gmtime

        parse_committee_info File.read(file)
      end
    end

    # update next month section.  Remove entries that have reported or
    # or expired; add (or update) entries that are missing; add entries
    # for new committees.
    def self.update_next_month(contents, date, missing, rejected, todos)
      # extract next month section; and then extract the lines containing
      # '#' signs from within that section
      next_month = contents[/Next month.*?\n\n/m].chomp
      block = next_month[/(.*#.*\n)+/] || ''

      # remove expired entries
      month = date.strftime("%B")
      block.gsub!(/.* # new, monthly through #{month}\n/, '')

      # update/remove existing 'missing' entries
      existing = []
      block.gsub! /(.*?)# (missing|not accepted) in .*\n/ do |line|
        if rejected.include? $1.strip
          existing << $1.strip
          if line.chomp.end_with? month
            line
          else
            "#{line.chomp}, not accepted #{month}\n"
          end
        elsif missing.include? $1.strip
          existing << $1.strip
          if line.chomp.end_with? month
            line
          elsif line.split(',').last.include? 'not accepted'
            "#{line.chomp}, missing #{month}\n"
          else
            "#{line.chomp}, #{month}\n"
          end
        else
          ''
        end
      end

      # add new 'rejected' entries
      (rejected-existing).each do |pmc|
        block += "    #{pmc.ljust(22)} # not accepted in #{month}\n"
      end

      # add new 'missing' entries
      (missing-rejected-existing).each do |pmc|
        block += "    #{pmc.ljust(22)} # missing in #{month}\n"
      end

      # add new 'established' entries and remove 'terminated' entries
      month = (date+91).strftime('%B')
      todos.each do |resolution|
        pmc = resolution['display_name']
        if resolution['action'] == 'terminate'
          block.sub! /^    #{pmc.ljust(22)} # .*\n/, ''
        elsif resolution['action'] == 'establish' and not existing.include? pmc
          block += "    #{pmc.ljust(22)} # new, monthly through #{month}\n"
        end
      end

      # replace/append block
      if next_month.include? '#'
        next_month[/(.*#.*\n)+/] = block.split("\n").sort.join("\n")
      else
        next_month += block
      end

      # replace next month section
      contents[/Next month.*?\n\n/m] = next_month + "\n\n"

      # return result
      contents
    end

    # update chairs
    def self.update_chairs(contents, todos)
      # extract committee section; and then extract the lines containing
      # committee names and chairs
      section = contents[/^1\..*?\n=+/m]
      committees = section[/-\n(.*?)\n\n/m, 1].scan(/^ +(.*?)  +(.*)/).to_h

      # update/add chairs based on resolutions
      todos.each do |resolution|
        name = resolution['display_name']
        if resolution['action'] == 'terminate'
          committees.delete(name)
        elsif resolution['chair']
          person = ASF::Person.find(resolution['chair'])
          committees[name] = "#{person.public_name} <#{person.id}@apache.org>"
        end
      end

      # sort and concatenate committees
      committees = committees.sort_by {|name, chair| name.downcase}.
        map {|name, chair| "    #{name.ljust(23)} #{chair}"}.
        join("\n")

      # replace committee info in the section, and then replace the
      # section in the committee-info contents
      section[/-\n(.*?)\n\n/m, 1] = committees
      contents[/^1\..*?\n=+/m] = section

      # return result
      contents
    end

    # remove committee from committee-info.txt
    def self.terminate(contents, pmc)
      ########################################################################
      #         remove from assigned quarterly reporting periods             #
      ########################################################################

      # split into blocks
      blocks = contents.split("\n\n")

      # find the reporting schedules
      index =  blocks.find_index {|section| section =~/January/}

      # remove from each reporting period 
      blocks[index+0].sub! "\n    #{pmc}\n", "\n"
      blocks[index+1].sub! "\n    #{pmc}\n", "\n"
      blocks[index+2].sub! "\n    #{pmc}\n", "\n"

      # re-attach blocks
      contents = blocks.join("\n\n")

      ########################################################################
      #         remove from COMMITTEE MEMBERSHIP AND CHANGE PROCESS          #
      ########################################################################

      contents.sub! /^\* #{pmc}  \(est.*?\n\n+/m, ''

      contents
    end

    # insert (replacing if necessary) a new committee into committee-info.txt
    def self.establish(contents, pmc, date, people)
      ########################################################################
      #         insert into assigned quarterly reporting periods             #
      ########################################################################

      # split into blocks
      blocks = contents.split("\n\n")

      # find the reporting schedules
      index =  blocks.find_index {|section| section =~/January/}

      # extract reporting schedules
      slots = [
        blocks[index+0].split("\n"),
        blocks[index+1].split("\n"),
        blocks[index+2].split("\n"),
      ]

      unless slots.any? {|slot| slot.include? "    " + pmc}
        # ensure that spacing is uniform
        slots.each {|slot| slot.unshift '' unless slot[0] == ''}

        # determine tie breakers between months of the same length
        preference = [(date.month)%3, (date.month-1)%3, (date.month-2)%3]

        # pick the month with the shortest list
        slot = (0..2).map {|i| [slots[i].length, preference, i]}.min.last

        # temporarily remove headers
        headers = slots[slot].shift(3)

        # insert pmc into the reporting schedule
        slots[slot] << "    " + pmc

        # sort entries, case insensitive
        slots[slot].sort_by!(&:downcase)

        #restore headers
        slots[slot].unshift *headers

        # re-insert reporting schedules
        blocks[index+0] = slots[0].join("\n")
        blocks[index+1] = slots[1].join("\n")
        blocks[index+2] = slots[2].join("\n")

        # re-attach blocks
        contents = blocks.join("\n\n")
      end

      ########################################################################
      #         insert into COMMITTEE MEMBERSHIP AND CHANGE PROCESS          #
      ########################################################################

      # split into foot, sections (array) and head
      foot = contents[/^=+\s*\Z/]
      contents.sub! /^=+\s*\Z/, ''
      sections = contents.split(/^\* /)
      head = sections.shift

      # remove existing section (if present)
      sections.delete_if {|section| section.downcase.start_with? pmc.downcase}

      # build new section
      people = people.map do |id, person|
        name = "#{person[:name].ljust(26)} <#{id}@apache.org>"
        "    #{(name).ljust(59)} [#{date.strftime('%Y-%m-%d')}]"
      end

      section  = ["#{pmc}  (est. #{date.strftime('%m/%Y')})"] + people.sort

      # add new section
      sections << section.join("\n") + "\n\n\n"

      # sort sections
      sections.sort_by!(&:downcase)

      # re-attach parts
      head + '* ' + sections.join('* ') + foot
    end

    # extract chairs, list of nonpmcs, roster, start date, and reporting
    # information from <tt>committee-info.txt</tt>.  Note: this method is
    # intended to be internal, use ASF::Committee.load_committee_info as it
    # will cache this data.
    def self.parse_committee_info(contents)
      # List uses full (display) names as keys, but the entries use the canonical names
      # - the local version of find() converts the name
      # - and stores the original as the display name if it has some upper case
      list = Hash.new {|hash, name| hash[name] = find(name)}

      # Split the file on lines starting "* ", i.e. the start of each group in section 3
      info = contents.split(/^\* /)
      # Extract the text before first entry in section 3 and split on section headers,
      # keeping sections 1 (COMMITTEES) and 2 (REPORTING).
      head, report = info.shift.split(/^\d\./)[1..2]
      # Drop lines which could match group headers
      head.gsub! /^\s+NAME\s+CHAIR\s*$/,''
      head.gsub! /^\s+Office\s+Officer\s*$/i,''

      # extract the committee chairs (e-mail address is required here)
      # Note: this includes the non-PMC entries

      # Scan for entries even if there is a missing extra space before the chair column
      head.scan(/^[ \t]+\w.*?[ \t]+.*[ \t]+<.*?@apache\.org>/).each do |line|
        # Now weed out the malformed lines
        m = line.match(/^[ \t]+(\w.*?)[ \t][ \t]+(.*)[ \t]+<(.*?)@apache\.org>/)
        if m
          committee, name, id = m.captures
          unless list[committee].chairs.any? {|chair| chair[:id] == id}
            list[committee].chairs << {name: name, id: id}
          end
        else
          # not possible to determine where one name starts and the other begins
          Wunderbar.warn "Missing separator before chair name in: '#{line}'"
        end
      end
      # Extract the non-PMC committees (e-mail address may be absent)
      # first drop leading text (and Officers) so we only match non-PMCs
      @nonpmcs = head.sub(/.*?also has /m,'').sub(/ Officers:.*/m,'').
        scan(/^[ \t]+(\w.*?)(?:[ \t][ \t]|[ \t]?$)/).flatten.uniq.
        map {|name| list[name]}

      # Extract officers
      # first drop leading text so we only match officers at end of section
      @officers = head.sub(/.*?also has .*? Officers/m,'').
        scan(/^[ \t]+(\w.*?)(?:[ \t][ \t]|[ \t]?$)/).flatten.uniq.
        map {|name| list[name]}

      # for each committee in section 3
      info.each do |roster|
        # extract the committee name (and parenthesised comment if any)
        name = roster[/(\w.*?)[ \t]+\(est/,1]
        unless list.include?(name)
          Wunderbar.warn "No chair entry detected for #{name} in section 3"
        end
        committee = list[name]

        # get and normalize the start date
        established = roster[/\(est\. (.*?)\)/, 1]
        established = "0#{established}" if established =~ /^\d\//
        committee.established = established

        # match non-empty entries and check the syntax
        roster.scan(/^[ \t]+.+$/) do |line|
            Wunderbar.warn "Invalid syntax: #{committee.name} '#{line}'" unless line =~ /\s<(.*?)@apache\.org>\s/
        end

        # extract the availids (is this used?)
        committee.info = roster.scan(/<(.*?)@apache\.org>/).flatten

        # drop (chair) markers and extract 0: name, 1: availid, 2: [date], 3: date
        # the date is optional (e.g. infrastructure)
        committee.roster = Hash[roster.gsub(/\(\w+\)/, '').
          scan(/^[ \t]*(.*?)[ \t]*<(.*?)@apache\.org>(?:[ \t]+(\[(.*?)\]))?/).
          map {|list| [list[1], {name: list[0], date: list[3]}]}]
      end

      # process report section
      report.scan(/^([^\n]+)\n---+\n(.*?)\n\n/m).each do |period, committees|
        committees.scan(/^   [ \t]*(.*)/).each do |committee|
          committee, comment = committee.first.split(/[ \t]+#[ \t]+/,2)
          unless list.include? committee
            Wunderbar.warn "Unexpected name '#{committee}' in report section; ignored"
            next
          end
          committee = list[committee]
          if comment
            committee.report = "#{period}: #{comment}"
          elsif period == 'Next month'
            committee.report = 'Every month'
          else
            committee.schedule = period
          end
        end
      end
      @committee_info = (list.values - @officers).uniq
      # Check if there are duplicates.
      @committee_info.each do |c|
        if c.chairs.length != 1 && c.name != 'fundraising' # hack to avoid reporting non-PMC entry
          Wunderbar.warn "Unexpected chair count for #{c.display_name}: #{c.chairs.inspect rescue ''}"
        end
      end
      @committee_info
    end

    # return a list of PMC committees.  Data is obtained from
    # <tt>committee-info.txt</tt>
    def self.pmcs
      committees = ASF::Committee.load_committee_info
      committees - @nonpmcs - @officers
    end

    # return a list of non-PMC committees.  Data is obtained from
    # <tt>committee-info.txt</tt>
    def self.nonpmcs
      ASF::Committee.load_committee_info # ensure data exists
      @nonpmcs
    end

    # return a list of officers.  Data is obtained from
    # <tt>committee-info.txt</tt>.  Note that these entries are returned
    # as instances of ASF::Committee with display_name being the name of
    # the office, and chairs being the individuals who hold that office.
    def self.officers
      ASF::Committee.load_committee_info # ensure data exists
      @officers
    end

    # Finds a committee based on the name of the Committee.  Is aware of
    # a number of aliases for a given committee.  Will set display name
    # if the name being searched on contains an uppercase character.
    def self.find(name)
      raise ArgumentError.new('name: must not be nil') unless name
      result = super(@@namemap.call(name.downcase))
      result.display_name = name if name =~ /[A-Z]/
      result
    end

    # Return the Last Changed Date for <tt>committee-info.txt</tt> in svn as
    # a <tt>Time</tt> object.  Data is based on the previous call to
    # ASF::Committee.load_committee_info.
    def self.svn_change
      @@svn_change
    end

    # returns the (first) chair as an instance of the ASF::Person class.
    def chair
      Committee.load_committee_info
      if @chairs.length >= 1
        ASF::Person.find(@chairs.first[:id])
      else
        nil
      end
    end

    # Version of name suitable for display purposes.  Typically in uppercase.
    # Data is sourced from <tt>committee-info.txt</tt>.
    def display_name
      Committee.load_committee_info
      @display_name || name
    end

    # setter for display_name, should only be used by
    # ASF::Committee.load_committee_info
    def display_name=(name)
      @display_name ||= name
    end

    # when this committee is next expected to report.  May be a string
    # containing values such as "Next month: missing in May", "Next month: new,
    # montly through July".  Or may be a list of months, separated by commas.
    # Data is obtained from <tt>committee-info.txt</tt>.
    def report
      @report || @schedule
    end

    # setter for display_name, should only be used by
    # ASF::Committee.load_committee_info
    def info=(list)
      @info = list
    end

    # hash of availid => public_name for members (owners) of this committee
    # Data is obtained from <tt>committee-info.txt</tt>.
    def names
      Committee.load_committee_info
      Hash[@roster.map {|id, info| [id, info[:name]]}]
    end

    # if true, this committee is not a PMC.  
    # Data is obtained from <tt>committee-info.txt</tt>.
    def nonpmc?
      Committee.load_committee_info # ensure data is there
      Committee.nonpmcs.include? self
    end

    # if true, this committee is a PMC.  
    # Data is obtained from <tt>committee-info.txt</tt>.
    def pmc?
      Committee.load_committee_info # ensure data is there
      Committee.pmcs.include? self
    end
  end
end
