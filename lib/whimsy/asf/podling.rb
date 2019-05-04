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

require 'nokogiri'
require 'date'
require 'psych'
require_relative '../asf'

module ASF

  # Represents a podling, drawing information from both podlings.xml and LDAP.

  class Podling
    include Enumerable

    # name of the podling, from podlings.xml
    attr_writer :name

    # name of the podling, from podlings.xml
    attr_accessor  :resource

    # array of aliases for the podling, from podlings.xml
    attr_accessor  :resourceAliases

    # status of the podling, from podlings.xml.  Valid values are
    # <tt>current</tt>, <tt>graduated</tt>, or <tt>retired</tt>.
    attr_accessor  :status

    # description of the podling, from podlings.xml
    attr_accessor  :description

    # list of userids of the mentors, from podlings.xml
    attr_accessor  :mentors

    # userid of the champion, from podlings.xml
    attr_accessor  :champion

    # list of months in the normal reporting schedule for this podling.
    attr_accessor  :reporting

    # if reporting monthly, a list of months reports are expected.  Can also
    # ge <tt>nil</tt> or an empty list.  From podlings.xml.
    attr_accessor  :monthly

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
      @sponsor = node['sponsor']
      # Needed for matching against mailing list names 
      @resourceAliases = []
      @resourceAliases = node['resourceAliases'].split(/,\s*/) if node['resourceAliases']
      @status = node['status']
      @enddate = node['enddate']
      @startdate = node['startdate']
      @description = node.at('description').text
      @mentors = node.search('mentor').map { |mentor| mentor['username'] }
      @champion = node.at('champion')['availid'] if node.at('champion')

      @reporting = node.at('reporting') if node.at('reporting')
      @monthly = @reporting.text.split(/,\s*/) if @reporting and @reporting.text

      @resolutionLink = node.at('resolution')['link'] if node.at('resolution')

      # Note: the following optional elements are not currently processed:
      # - resolution (except for resolution/@link)
      # - retiring/graduating
      # The following podling attributes are not processed:
      # - longname
    end

    # name for this podling, originally from the resource attribute in
    # podlings.xml.
    def name
      @resource
    end

    # also map resource to id
    def id
      @resource
    end

    # display name for this podling, originally from the name attribute in
    # podlings.xml.
    def display_name
      @name || @resource
    end

    # TLP name (name differ from podling name)
    def tlp_name
      @resolutionLink || name
    end

    # date this podling was accepted for incubation
    def startdate
      return unless @startdate
      # assume 15th (mid-month) if no day specified
      return Date.parse("#@startdate-15") if @startdate.length < 8
      Date.parse(@startdate)
    rescue ArgumentError
      nil
    end

    # date this podling either retired or graduated.  <tt>nil</tt> for
    # current podlings.
    def enddate
      return unless @enddate
      # assume 15th (mid-month) if no day specified
      return Date.parse("#@enddate-15") if @enddate.length < 8
      Date.parse(@enddate)
    rescue ArgumentError
      nil
    end

    # number of days in incubation
    def duration
      last = enddate || Date.today
      first = startdate || Date.today
      (last - first).to_i
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

    # list of all podlings, regardless of status
    def self.list
      incubator_content = ASF::SVN['incubator-content']
      podlings_xml = File.join(incubator_content, 'podlings.xml')

      # see if there is a later version
      cache = ASF::Config.get(:cache)
      if File.exist? File.join(cache, 'podlings.xml')
        if File.mtime(File.join(cache, 'podlings.xml')) > File.mtime(podlings_xml)
          podlings_xml = File.join(cache, 'podlings.xml')
        end
      end

      if @mtime != File.mtime(podlings_xml)
        @list = []
        podlings = Nokogiri::XML(File.read(podlings_xml))
        # check for errors as they adversely affect the generated output
        raise Exception.new("#{podlings.errors.inspect}") if podlings.errors.size > 0
        podlings.search('podling').map do |node|
          @list << new(node)
        end
        @mtime = File.mtime(podlings_xml)
      end

      @list
    end

    # list of current podlings
    def self.current
      self._list('current')
    end

    # list of current podling ids
    def self.currentids
      self._listids('current')
    end

    # list of graduated podlings
    def self.graduated
      self._list('graduated')
    end

    # list of graduated podling ids
    def self.graduatedids
      self._listids('graduated')
    end

    # list of retired podlings
    def self.retired
      self._list('retired')
    end

    # list of retired podling ids
    def self.retiredids
      self._listids('retired')
    end

    # last modified time of podlings.xml in the local working directory,
    # as of the last time #list was called.
    def self.mtime
      @mtime
    end

    # find a podling by name
    def self.find(name)
      name = name.downcase

      result = list.find do |podling| 
        podling.name == name or podling.display_name.downcase == name or
          podling.resourceAliases.any? {|aname| aname.downcase == name}
      end

      result ||= list.find do |podling| 
        podling.resource == name or
        podling.tlp_name.downcase == name
      end
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
      list.each { |podling| block.call podling.name, podling }
    end

    # allow attributes to be accessed as hash
    def [](name)
      return self.send name if self.respond_to? name
    end

    # list of PPMC owners from LDAP
    def owners
      ASF::Project.find(id).owners
    end

    # list of PPMC committers from LDAP
    def members
      ASF::Project.find(id).members
    end

    def hasLDAP?
      ASF::Project.find(id).hasLDAP?
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
      @resourceAliases.each { |name|
        return true if _match_mailname?(list, name)
      }
      return false
    end

    # Match against new and old list types
    def _match_mailname?(list, _name)
      return true if list.start_with?("#{_name}-")
      return true if list.start_with?("incubator-#{_name}-")
    end

    # status information associated with this podling.  Keys in the hash return
    # include: <tt>:ipClearance</tt>, <tt>:sourceControl</tt>, <tt>:wiki</tt>,
    # <tt>:jira</tt>, <tt>:proposal</tt>, <tt>:website</tt>, <tt>:news</tt>
    def podlingStatus
      # resource can contain '-'
      @resource.untaint if @resource =~ /\A[-\w]+\z/
      incubator_content = ASF::SVN['incubator-podlings']
      resource_yml = File.join(incubator_content, "#{@resource}.yml")
      if File.exist?(resource_yml)
        rawYaml = Psych.load_file(resource_yml)
        hash = { }
        hash[:sga] = rawYaml[:sga].strftime('%Y-%m-%d') if rawYaml[:sga]
        hash[:asfCopyright] = rawYaml[:asfCopyright].strftime('%Y-%m-%d') if rawYaml[:asfCopyright]
        hash[:distributionRights] = rawYaml[:distributionRights].strftime('%Y-%m-%d') if rawYaml[:distributionRights]
        hash[:ipClearance] = rawYaml[:ipClearance]
        hash[:sourceControl] = rawYaml[:sourceControl]
        hash[:wiki] = rawYaml[:wiki]
        hash[:jira] = rawYaml[:jira]
        hash[:proposal] = rawYaml[:proposal]
        hash[:website] = rawYaml[:website]
        hash[:news] = []
        for ni in rawYaml[:news]
          newsItem = {}
          newsItem[:date] = ni[:date].strftime('%Y-%m-%d')
          newsItem[:note] = ni[:note]
          hash[:news].push(newsItem)
        end if rawYaml[:news]
        hash
      else
        {news: [], website: 'http://'+self.resource+'.incubator.apache.org',}
      end
    end

    # Return the instance as a hash.  Keys in the hash are:
    # <tt>:name</tt>, <tt>:status</tt>, <tt>:description</tt>,
    # <tt>:mentors</tt>, <tt>:startdate</tt>, <tt>:champion</tt>,
    # <tt>:reporting</tt>, <tt>:resource</tt>, <tt>:resourceAliases</tt>,
    # <tt>:sponsor</tt>, <tt>:duration</tt>, and <tt>:podlingStatus</tt>
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
      hash[:sponsor] = @sponsor if @sponsor
      hash[:duration] = self.duration
      hash[:podlingStatus] = podlingStatus
      hash
    end

    # status information associated with this podling.  Keys in the hash return
    # include: <tt>:issueTracker</tt>, <tt>:wiki</tt>, <tt>:jira</tt>,
    # <tt>:proposal</tt>, <tt>:asfCopyright, <tt>:distributionRights</tt>,
    # <tt>:ipClearance</tt>, <tt>:sga</tt>, <tt>:website</tt>,
    # <tt>:graduationDate</tt>, <tt>:resolution</tt>
    def default_status
      {
          issueTracker: 'jira',
          wiki: self.resource.upcase,
          jira: self.resource.upcase,
          proposal: 'http://wiki.apache.org/incubator/'+self.resource.capitalize+"Proposal",
          asfCopyright: nil,
          distributionRights: nil,
          ipClearance: nil,
          sga: nil,
          website: 'http://'+self.resource+'.incubator.apache.org',
          graduationDate: nil,
          resolution: nil
      }
    end

    # parse (and cache) names mentioned in podlingnamesearches
    def self.namesearch
      # cache JIRA response
      cache = File.join(ASF::Config.get(:cache), 'pns.jira')
      if not File.exist?(cache) or File.mtime(cache) < Time.now - 300
        query = 'https://issues.apache.org/jira/rest/api/2/search?' +
            'maxResults=1000&' +
            'jql=project=PODLINGNAMESEARCH&fields=summary,resolution,customfield_12310520'
        begin
          res = Net::HTTP.get_response(URI(query))
          res.value() # Raises error if not OK
          file = File.new(cache,"wb") # Allow for non-UTF-8 chars
          file.write res.body
        rescue => e
          Wunderbar.warn "ASF::Podling.namesearch: " + e.message
          FileUtils.touch cache # Don't try again for a while
        end
      end

      # parse JIRA titles for proposed name
      issues = JSON.parse(File.read(cache))['issues'].map do |issue|
        title = issue['fields']['summary'].strip.gsub(/\s+/, ' ')
        name = issue['fields']['customfield_12310520']

        if name
          name.sub! /^Apache\s+/, ''
          name.gsub! /\s+\(.*?\)/, ''
          name = nil if name =~ /^This/ or name !~ /[A-Z]/
        end

        name ||= title[/"Apache ([a-zA-Z].*?)"/, 1]
        name ||= title[/'Apache ([a-zA-Z].*?)'/, 1]
        name ||= title[/.*Apache ([A-Z]\S*)/, 1]
        name ||= title.gsub('Apache', '')[/.*\b([A-Z]\S*)/, 1]
        next unless name
        resolution = issue['fields']['resolution']
        resolution = resolution ? resolution['name'] : 'Unresolved'
        [name, {issue: issue['key'], resolution: resolution}]
      end

      issues.compact.sort_by(&:first).to_h
    end

    # return podlingnamesearch for this podling
    def namesearch
      Podling.namesearch[display_name]
    end
    
    private
    
    def self._list(status)
      list.select { |podling| podling.status == status }
    end

    def self._listids(status)
      list.select { |podling| podling.status == status }.map(&:id)
    end
  end
end
