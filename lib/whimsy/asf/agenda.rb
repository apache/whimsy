require_relative '../asf'

require 'time'
require 'tzinfo'
require 'tzinfo/data'
require 'digest/md5'

module ASF
  module Board
  end
end

class ASF::Board::Agenda
  CONTENTS = {
    '2.' => 'Roll Call',
    '3A' => 'Minutes',
    '4A' => 'Executive Officer',
    '1'  => 'Additional Officer',
    'A'  => 'Committee Reports',
    '7A' => 'Special Orders',
    '8.' => 'Discussion Items',
    '9.' => 'Action Items'
  }

  @@parsers = []
  def self.parse(file=nil, quick=false, &block)
    @@parsers << block if block
    new.parse(file, quick)  if file
  end

  def initialize
    @sections = {}
  end

  def scan(text, pattern, &block)
    # convert tabs to spaces
    text.gsub!(/^(\t+)/) {|tabs| ' ' * (8*tabs.length)}

    text.scan(pattern).each do |matches|
      hash = Hash[pattern.names.zip(matches)]
      yield hash if block

      section = hash.delete('section')
      section ||= hash.delete('attach')

      if section
        hash['approved'] &&= hash['approved'].strip.split(/[ ,]+/)

        @sections[section] ||= {}
        next if hash['text'] and @sections[section]['text']
        @sections[section].merge!(hash)
      end
    end
  end

  def parse(file, quick=false)
    @file = file
    @quick = quick
    
    if not @file.valid_encoding?
      filter = Proc.new {|c| c.unpack('U').first rescue 0xFFFD}
      @file = @file.chars.map(&filter).pack('U*').force_encoding('utf-8')
    end

    @@parsers.each { |parser| instance_exec(&parser) }

    # add index markers for major sections
    CONTENTS.each do |section, index|
      @sections[section][:index] = index if @sections[section]
    end

    # look for flags
    flagged_reports = Hash[@file[/ \d\. Committee Reports.*?\n\s+A\./m].
      scan(/# (.*?) \[(.*)\]/)]

    # cleanup text and comment whitespace, add flags
    @sections.each do |section, hash|
      text = hash['text'] || hash['report']
      if text
        text.sub!(/\A\s*\n/, '')
        text.sub!(/\s+\Z/, '')
        unindent = text.sub(/s+\Z/,'').scan(/^ *\S/).map(&:length).min || 1
        text.gsub! /^ {#{unindent-1}}/, ''
      end

      text = hash['comments']
      if text
        text.sub!(/\A\s*\n/, '')
        text.sub!(/\s+\Z/, '')
        unindent = text.sub(/s+\Z/,'').scan(/^ *\S/).map(&:length).min || 1
        text.gsub! /^ {#{unindent-1}}/, ''
      end

      # add flags
      flags = flagged_reports[hash['title']]
      hash['flagged_by'] = flags.split(', ') if flags
    end

    unless @quick
      # add roster and prior report link
      whimsy = 'https://whimsy.apache.org'
      @sections.each do |section, hash|
        next unless section =~ /^(4[A-Z]|\d+|[A-Z][A-Z]?)$/
        committee = ASF::Committee.find(hash['title'] ||= 'UNKNOWN')
        unless section =~ /^4[A-Z]$/
          hash['roster'] = 
            "#{whimsy}/roster/committee/#{CGI.escape committee.name}"
        end
        if section =~ /^[A-Z][A-Z]?$/
          hash['stats'] = 
            "https://reporter.apache.org/?#{CGI.escape committee.name}"
        end
        hash['prior_reports'] = minutes(committee.display_name)
      end
    end

    # add attach to section
    @sections.each do |section, hash|
      hash[:attach] = section
    end

    @sections.values
  end

  def minutes(title)
    "https://whimsy.apache.org/board/minutes/#{title.gsub(/\W/,'_')}"
  end

  def timestamp(time)
    date = @file[/(\w+ \d+, \d+)/]
    tz = TZInfo::Timezone.get('America/Los_Angeles')
    tz.local_to_utc(Time.parse("#{date} #{time}")).to_i * 1000
  end
end

require_relative 'agenda/front'
require_relative 'agenda/minutes'
require_relative 'agenda/exec-officer'
require_relative 'agenda/attachments'
require_relative 'agenda/committee'
require_relative 'agenda/special'
require_relative 'agenda/back'
