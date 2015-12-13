require 'time'

module ASF

  class Base
  end

  class Committee < Base
    attr_accessor :info, :emeritus, :report, :roster, :established, :chairs,
      :schedule
    def initialize(*args)
      @info = []
      @emeritus = []
      @chairs = []
      @roster = {}
      super
    end

    # mapping of committee names to canonical names (generally from ldap)
    # See also www/roster/committee.cgi
    @@aliases = Hash.new {|hash, name| name}
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

      info = File.read(file).split(/^\* /)
      head, report = info.shift.split(/^\d\./)[1..2]
      head.gsub! /^\s+NAME\s+CHAIR\s*$/,'' # otherwise could match an entry with no e-mail

      # extract the committee chairs (e-mail address is required here)
      head.scan(/^[ \t]+(\w.*?)[ \t][ \t]+(.*)[ \t]+<(.*?)@apache\.org>/).
        each do |committee, name, id|
          find(committee).chairs << {name: name, id: id}
        end
      # Extract the non-PMC committees (e-mail address may be absent)
      @nonpmcs = head.sub(/.*?also has/m,'').
        scan(/^[ \t]+(\w.*?)(?:[ \t][ \t]|[ \t]?$)/).flatten.uniq.
        map {|name| find(name)}

      info.each do |roster|
        committee = find(@@namemap.call(roster[/(\w.*?)\s+\(/,1]))
        committee.established = roster[/\(est\. (.*?)\)/, 1]
        roster.gsub! /^.*\(\s*emeritus\s*\).*/i do |line|
          committee.emeritus += line.scan(/<(.*?)@apache\.org>/).flatten
          ''
        end
        committee.info = roster.scan(/<(.*?)@apache\.org>/).flatten
        committee.roster = Hash[roster.gsub(/\(\w+\)/, '').
          scan(/^\s*(.*?)\s*<(.*?)@apache\.org>\s+(\[(.*?)\])?/).
          map {|list| [list[1], {name: list[0], date: list[3]}]}]
      end

      report.scan(/^([^\n]+)\n---+\n(.*?)\n\n/m).each do |period, committees|
        committees.scan(/^   \s*(.*)/).each do |committee|
          committee, comment = committee.first.split(/\s+#\s+/,2)
          committee = find(committee)
          if comment
            committee.report = "#{period}: #{comment}"
          elsif period == 'Next month'
            committee.report = 'Every month'
          else
            committee.schedule = period
          end
        end
      end

      @committee_info = ASF::Committee.collection.values
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
