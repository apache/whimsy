require 'nokogiri'
require 'date'
require 'psych'
require_relative '../asf'

module ASF
  class Podling
    include Enumerable
    attr_accessor :name, :resource, :resourceAliases, :status, :description, :mentors, :champion, :reporting, :monthly

    # three consecutive months, starting with this one
    def quarter
      [
        Date.today.strftime('%B'),
        Date.today.next_month.strftime('%B'),
        Date.today.next_month.next_month.strftime('%B')
      ]
    end

    # create a podling from a Nokogiri node built from podlings.xml
    def initialize(node)
      @name = node['name']
      @resource = node['resource']
      # Needed for matching against mailing list names 
      @resourceAliases = []
      @resourceAliases = node['resourceAliases'].split(/,\s*/) if node['resourceAliases']
      @status = node['status']
      @enddate = node['enddate']
      @startdate = node['startdate']
      @description = node.at('description').text
      @mentors = node.search('mentor').map {|mentor| mentor['username']}
      @champion = node.at('champion')['availid'] if node.at('champion')

      @reporting = node.at('reporting') if node.at('reporting')
      @monthly = @reporting.text.split(/,\s*/) if @reporting and @reporting.text

      # Note: the following optional elements are not currently processed:
      # - resolution
      # - retiring/graduating
      # The following podling attributes are not processed:
      # - longname
      # - sponsor
    end

    # map resource to name
    def name
      @resource
    end

    # also map resource to id
    def id
      @resource
    end

    # map name to display_name
    def display_name
      @name || @resource
    end

    # parse startdate
    def startdate
      return unless @startdate
      # assume 15th (mid-month) if no day specified
      return Date.parse("#@startdate-15") if @startdate.length < 8
      Date.parse(@startdate)
    rescue ArgumentError
      nil
    end

    # parse enddate
    def enddate
      return unless @enddate
      # assume 15th (mid-month) if no day specified
      return Date.parse("#@enddate-15") if @enddate.length < 8
      Date.parse(@enddate)
    rescue ArgumentError
      nil
    end

    # lazy evaluation of reporting
    def reporting
      if @reporting.instance_of? Nokogiri::XML::Element
        group = @reporting['group']
        @reporting = %w(January April July October) if group == '1'
        @reporting = %w(February May August November) if group == '2'
        @reporting = %w(March June September December) if group == '3'
      end

      @reporting
    end

    # provides a concatenated reporting schedule
    def schedule
      self.reporting + self.monthly
    end

    # list of podlings
    def self.list
      incubator_content = ASF::SVN['asf/incubator/public/trunk/content']
      podlings_xml = "#{incubator_content}/podlings.xml"

      # see if there is a later version
      cache = ASF::Config.get(:cache)
      if File.exist? "#{cache}/podlings.xml"
        if File.mtime("#{cache}/podlings.xml") > File.mtime(podlings_xml)
          podlings_xml = "#{cache}/podlings.xml"
        end
      end

      if @mtime != File.mtime(podlings_xml)
        @list = []
        podlings = Nokogiri::XML(File.read(podlings_xml))
        podlings.search('podling').map do |node|
          @list << new(node)
        end
        @mtime = File.mtime(podlings_xml)
      end

      @list
    end

    def self.current
      list.select {|podling| podling.status == 'current'}
    end

    def self.mtime
      @mtime
    end

    # find a podling by name
    def self.find(name)
      list.find {|podling| podling.name == name}
    end

    # below is for backwards compatibility

    # make class itself enumerable
    class << self
      include Enumerable
    end

    # return the entire list as a hash
    def self.to_h
      Hash[self.to_a]
    end

    # provide a list of podling names and descriptions
    def self.each(&block)
      list.each {|podling| block.call podling.name, podling}
    end

    # allow attributes to be accessed as hash
    def [](name)
      return self.send name if self.respond_to? name
    end

    # list of PPMC owners
    def owners
      ASF::Project.find(id).owners
    end

    # list of PPMC members
    def members
      ASF::Project.find(id).members
    end

    # development mailing list associated with a given podling
    def dev_mail_list
      case name
      when 'climatemodeldiagnosticanalyzer'
        'dev@cmda.incubator.apache.org'
      when 'odftoolkit'
        'odf-dev@incubator.apache.org'
      when 'log4cxx2'
        'log4cxx-dev@logging.apache.org'
      else
        if ASF::Mail.lists.include? "#{name}-dev"
          "dev@#{name}.apache.org" 
        elsif ASF::Mail.lists.include? "incubator-#{name}-dev"
          "#{name}-dev@incubator.apache.org" 
        end
      end
    end

    # private mailing list associated with a given podling
    def private_mail_list
      if name == 'log4cxx2'
        'private@logging.apache.org'
      else
        list = dev_mail_list
        list ? list.sub('dev', 'private') : 'private@incubator.apache.org'
      end
    end

    # Is this a podling mailing list?
    def mail_list?(list)
      return true if _match_mailname?(list, name())
      # Also check aliases
      @resourceAliases.each {|name|
        return true if _match_mailname?(list, name)
      }
      return false
    end

    # Match against new and old list types
    def _match_mailname?(list, _name)
      return true if list.start_with?("#{_name}-")
      return true if list.start_with?("incubator-#{_name}-")
    end

    def podlingStatus
      incubator_content = ASF::SVN['asf/incubator/public/trunk/content/podlings']
      resource_yml = "#{incubator_content}/#{@resource}.yml"
      if File.exist?(resource_yml)
        Psych.load_file(resource_yml)
      else
        nil
      end
    end

    # Return the instance as a hash
    def as_hash # might be confusing to use to_h here?
      hash = {
        name: @name,
        status: status,
        description: description,
        mentors: mentors,
        startdate: startdate,
      }
      hash[:enddate] = enddate if enddate
      hash[:champion] = champion if champion

      # Tidy up the reporting output
      podlingStatus = self.podlingStatus
      r = @reporting
      if r.instance_of? Nokogiri::XML::Element
        group = r['group']
        hash[:reporting] = {
          group: group
        }
        hash[:reporting][:text] = r.text if r.text.length > 0
        hash[:reporting][:monthly] = r.text.split(/,\s*/) if r['monthly']
        hash[:reporting][:schedule] = self.schedule
      else
        hash[:reporting] = r if r
      end

      hash[:resource] = resource
      hash[:resourceAliases] = resourceAliases
      hash[:namesearch] = namesearch if namesearch
      hash[:podlingStatus] = podlingStatus if podlingStatus
      hash
    end

    # parse (and cache) names mentioned in podlingnamesearches
    def self.namesearch
      # cache JIRA response
      cache = "#{ASF::Config.get(:cache)}/pns.jira"
      if not File.exist?(cache) or File.mtime(cache) > Time.now - 300
        query = 'https://issues.apache.org/jira/rest/api/2/search?' +
          'jql=project=PODLINGNAMESEARCH&fields=summary,resolution'
        File.write cache, Net::HTTP.get(URI(query))
      end

      # parse JIRA titles for proposed name
      issues = JSON.parse(File.read(cache))['issues'].map do |issue|
        title = issue['fields']['summary']
        name = title[/"Apache ([A-Z].*?)"/, 1]
        name ||= title[/'Apache ([A-Z].*?)'/, 1]
        name ||= title[/.*Apache ([A-Z]\S*)/, 1]
        name ||= title.gsub('Apache', '')[/.*\b([A-Z]\S*)/, 1]
        next unless name
        resolution = issue['fields']['resolution']
        resolution = resolution ? resolution['name'] : 'Unresolved'
        [name, {issue: issue['key'], resolution: resolution}]
      end

      issues.sort.to_h
    end

    # return podlingnamesearch for this podling
    def namesearch
      Podling.namesearch[display_name]
    end
  end

  # more backwards compatibility
  Podlings = Podling
end
