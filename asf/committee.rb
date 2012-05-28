module ASF

  class Base
  end

  class Committee < Base
    @@aliases = Hash.new {|hash, name| name}
    @@aliases.merge! \
      'community development'       => 'comdev',
      'conference planning'         => 'concom',
      'conferences'                 => 'concom',
      'http server'                 => 'httpd',
      'httpserver'                  => 'httpd',
      'java community process'      => 'jcp',
      'quetzalcoatl'                => 'quetz',
      'security team'               => 'security',
      'c++ standard library'        => 'stdcxx',
      'travel assistance'           => 'tac',
      'traffic server'              => 'trafficserver',
      'web services'                => 'ws',
      'xml graphics'                => 'xmlgraphics'

    def self.load_committee_info
      return @committee_info if @committee_info
      board = ASF::SVN['private/committers/board']
      committee = File.read("#{board}/committee-info.txt").split(/^\* /)
      head = committee.shift.split(/^\d\./)[1]
      head.scan(/^\s+(\w.*?)\s\s+.*<(\w+)@apache\.org>/).each do |name, id|
        find(name).chair = ASF::Person.find(id) 
      end
      @nonpmcs = head.sub(/.*?also has/m,'').
        scan(/^\s+(\w.*?)\s\s+.*<\w+@apache\.org>/).flatten.uniq.
        map {|name| find(name)}
      @committee_info = ASF::Committee.collection.values
    end

    def self.nonpmcs
      @nonpmcs
    end

    def self.find(name)
      result = super(@@aliases[name.downcase])
      result.display_name = name if name =~ /[A-Z]/
      result
    end

    def chair
      Committee.load_committee_info
      @chair
    end

    def display_name
      Committee.load_committee_info
      @display_name || name
    end

    def display_name=(name)
      @display_name ||= name
    end

    def chair=(person)
      @chair = person
    end

    def nonpmc?
      Committee.nonpmcs.include? self
    end
  end
end
