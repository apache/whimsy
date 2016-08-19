require 'nokogiri'
require 'date'
require_relative '../asf'

module ASF
  class Podling
    include Enumerable
    attr_accessor :name, :status, :description, :mentors, :champion, :reporting

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
      @status = node['status']
      @enddate = node['enddate']
      @startdate = node['startdate']
      @description = node.at('description').text
      @mentors = node.search('mentor').map {|mentor| mentor['username']}
      @champion = node.at('champion')['availid'] if node.at('champion')

      @reporting = node.at('reporting')
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
        monthly = @reporting.text.split(/,\s*/) if @reporting['monthly']
        @reporting = %w(January April July October) if group == '1'
        @reporting = %w(February May August November) if group == '2'
        @reporting = %w(March June September December) if group == '3'
        @reporting.rotate! until quarter.include? @reporting.first

        if monthly
          monthly.shift until monthly.empty? or quarter.include? monthly.first
          @reporting = (monthly + @reporting).uniq
        end
      end

      @reporting
    end

    # list of podlings
    def self.list
      incubator_content = ASF::SVN['asf/incubator/public/trunk/content']
      podlings_xml = "#{incubator_content}/podlings.xml"

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

    # development mailing list associated with a given podling
    def dev_mail_list
      case name
      when 'climatemodeldiagnosticanalyzer'
        'dev@cmda.incubator.apache.org'
      when 'blur'
        'blur-dev@incubator.apache.org'
      when 'wave'
        'wave-dev@incubator.apache.org'
      when 'log4cxx2'
        'log4cxx-dev@logging.apache.org'
      else
        "dev@#{name}.apache.org"
      end
    end
  end

  # more backwards compatibility
  Podlings = Podling
end
