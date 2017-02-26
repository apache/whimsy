require 'time'

module ASF

  class Base
  end

  class Committee < Base
    attr_accessor :info, :report, :roster, :established, :chairs,
      :schedule
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
      'conference planning'         => 'concom',
      'conferences'                 => 'concom',
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
      'traffic server'              => 'trafficserver',
      'web services'                => 'ws',
      'xml graphics'                => 'xmlgraphics',
      'incubating'                  => 'incubator' # special for index.html

    @@namemap = Proc.new do |name|
      cname = @@aliases[name.sub(/\s+\(.*?\)/, '').downcase]
      cname
    end

    def self.load_committee_info
      board = ASF::SVN['private/committers/board']
      file = "#{board}/committee-info.txt"
      return unless File.exist? file

      if @committee_info and File.mtime(file) == @committee_mtime
        return @committee_info 
      end


      @committee_mtime = File.mtime(file)
      @@svn_change = Time.parse(
        `svn info #{file}`[/Last Changed Date: (.*) \(/, 1]).gmtime

      parse_committee_info File.read(file)
    end

    # insert (replacing if necessary) a new committee
    def self.establish(contents, pmc, date, people)
      # split into foot, sections (array) and head
      foot = contents[/^=+\s*\Z/]
      contents.sub! /^=+\s*\Z/, ''
      sections = contents.split(/^\* /)
      head = sections.shift

      # remove existing section (if present)
      sections.delete_if {|section| section.downcase.start_with? pmc.downcase}

      # build new section
      section  = ["#{pmc}  (est. #{date.strftime('%m/%Y')})"]
      people.sort.each do |id, name|
        name = "#{name.ljust(26)} <#{id}@apache.org>"
        section << "    #{(name).ljust(59)} [#{date.strftime('%Y-%m-%d')}]"
      end

      # add new section
      sections << section.join("\n") + "\n\n\n"

      # sort sections
      sections.sort_by!(&:downcase)

      # re-attach parts
      head + '* ' + sections.join('* ') + foot
    end

    def self.parse_committee_info(contents)
      list = Hash.new {|hash, name| hash[name] = find(name)}

      # Split the file on lines starting "* ", i.e. the start of each group in section 3
      info = contents.split(/^\* /)
      # Extract the text before first entry in section 3 and split on section headers,
      # keeping sections 1 (COMMITTEES) and 2 (REPORTING).
      head, report = info.shift.split(/^\d\./)[1..2]
      # Drop lines which could match group entries
      head.gsub! /^\s+NAME\s+CHAIR\s*$/,'' # otherwise could match an entry with no e-mail

      # extract the committee chairs (e-mail address is required here)
      # Note: this includes the non-PMC entries
      head.scan(/^[ \t]+(\w.*?)[ \t][ \t]+(.*)[ \t]+<(.*?)@apache\.org>/).
        each do |committee, name, id|
          list[committee].chairs << {name: name, id: id}
        end

      # Extract the non-PMC committees (e-mail address may be absent)
      # first drop leading text so we only match non-PMCs
      @nonpmcs = head.sub(/.*?also has /m,'').
        scan(/^[ \t]+(\w.*?)(?:[ \t][ \t]|[ \t]?$)/).flatten.uniq.
        map {|name| list[name]}

      # for each committee in section 3
      info.each do |roster|
        # extract the committee name and canonicalise
        committee = list[@@namemap.call(roster[/(\w.*?)[ \t]+\(/,1])]

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

      @committee_info = list.values.uniq
    end

    def self.nonpmcs
      @nonpmcs
    end

    def self.find(name)
      result = super(@@namemap.call(name))
      result.display_name = name if name =~ /[A-Z]/
      result
    end

    def self.svn_change
      @@svn_change
    end

    def chair
      Committee.load_committee_info
      if @chairs.length >= 1
        ASF::Person.find(@chairs.first[:id])
      else
        nil
      end
    end

    def display_name
      Committee.load_committee_info
      @display_name || name
    end

    def display_name=(name)
      @display_name ||= name
    end

    def report
      @report || @schedule
    end

    def info=(list)
      @info = list
    end

    def names
      Committee.load_committee_info
      Hash[@roster.map {|id, info| [id, info[:name]]}]
    end

    def nonpmc?
      Committee.nonpmcs.include? self
    end
  end
end
