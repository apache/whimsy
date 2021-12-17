require_relative '../asf'

require 'time'
require 'active_support'
require 'active_support/time'
require 'digest/md5'

module ASF
  #
  # module which contains the Agenda class
  #
  module Board
  end
end

#
# Class which contains a number of parsers.
#
class ASF::Board::Agenda
  # mapping of agenda section numbers to section names
  CONTENTS = {
    '2.' => 'Roll Call',
    '3A' => 'Minutes',
    '4A' => 'Executive Officer',
    '1'  => 'Additional Officer',
    'A'  => 'Committee Reports',
    '7A' => 'Special Orders',
    '8.' => 'Discussion Items',
    '8A' => 'Discussion Items',
    '9.' => 'Action Items'
  }

  # Regex for start of officer reports (accounts for style differences in early agendas)
  OFFICER_SEPARATOR = /^\s*4. (Executive )?Officer Reports/

  @@parsers = []
  # convenience method.  If passed a file, will create an instance of this
  # class and call the parse method on that object.  If passed a block, will
  # add that block to the list of parsers.
  def self.parse(file=nil, quick=false, &block)
    @@parsers << block if block
    new.parse(file, quick) if file
  end

  # start with an empty list of sections.  Sections are added and returned by
  # calling the <tt>parse</tt> method.
  def initialize
    @sections = {}
  end

  # helper method to scan a section for a pattern.  Regular expression named
  # matches will be captured and the section will be added to <tt>@sections</tt>
  # if a match is found.
  def scan(text, pattern, &block)
    # convert tabs to spaces
    text.gsub!(/^(\t+)/) {|tabs| ' ' * (8 * tabs.length)}

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

  # parse a board agenda file by passing it through each parser.  Additionally,
  # converts the file to utf-8, adds index markers for major sections, looks
  # for flagged reports, and performs various minor cleanup actions.
  #
  # If <tt>quick</tt> is <tt>false</tt>, cross-checks with committee membership
  # will be performed.  This supports the board agenda tools's strategy to
  # quickly display possibly stale and possible incomplete data and then to
  # update the presentation using React.JS once later and/or more complete
  # data is available.
  #
  # Returns a list of sections.
  def parse(file, quick=false)
    @file = file
    @quick = quick

    unless @file.valid_encoding?
      filter = proc {|c| c.unpack1('U') rescue 0xFFFD}
      @file = @file.chars.map(&filter).pack('U*').force_encoding('utf-8')
    end

    @@parsers.each { |parser| instance_exec(&parser) }

    # add index markers for major sections
    CONTENTS.each do |section, index|
      @sections[section][:index] = index if @sections[section]
    end

    # quick exit if none found -- non-standard format agenda
    return [] if @sections.empty?

    # look for flags
    flagged_reports = Hash[@file[/ \d\. Committee Reports.*?\n\s+A\./m].
      scan(/# (.*?) \[(.*)\]/)] rescue {}

    president = @sections.values.find {|item| item['title'] == 'President'}
    return [] unless president # quick exit if non-standard format agenda
    pattach = president['report'][/\d+ through \d+\.$/]
    # pattach is nil before https://whimsy.apache.org/board/minutes/Change_Officers_to_Serve_at_the_Direction_of_the_President.html
    preports = Range.new(*pattach.scan(/\d+/)) if pattach
    # cleanup text and comment whitespace, add flags
    @sections.each do |section, hash|
      text = hash['text'] || hash['report']
      if text
        text.sub!(/\A\s*\n/, '')
        text.sub!(/\s+\Z/, '')
        unindent = text.sub(/s+\Z/, '').scan(/^ *\S/).map(&:length).min || 1
        text.gsub!(/^ {#{unindent - 1}}/, '')
      end

      text = hash['comments']
      if text
        text.sub!(/\A\s*\n/, '')
        text.sub!(/\s+\Z/, '')
        unindent = text.sub(/s+\Z/, '').scan(/^ *\S/).map(&:length).min || 1
        text.gsub!(/^ {#{unindent - 1}}/, '')
      end

      # add flags
      flags = flagged_reports[hash['title']]
      hash['flagged_by'] = flags.split(', ') if flags

      # mark president reports
      hash['to'] = 'president' if preports&.include?(section)
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
          hash['stats'] = 'https://reporter.apache.org/wizard/statistics?' +
            CGI.escape(committee.name)
        end
        hash['prior_reports'] = minutes(committee.display_name)
      end
    end

    # add attach to section
    @sections.each do |section, hash|
      hash[:attach] = section

      # look for missing titles
      hash['title'] ||= "UNKNOWN"

      if hash['title'] == "UNKNOWN"
        hash['warnings'] = ['unable to find attachment']
      end
    end

    # handle case where board meeting crosses a date boundary
    if @sections.values.first['timestamp'] > @sections.values.last['timestamp']
      @sections.values.last['timestamp'] += 86_400_000 # add one day
    end

    @sections.values
  end

  # provide a link to the collated minutes for a given report
  def minutes(title)
    "https://whimsy.apache.org/board/minutes/#{title.gsub(/\W/, '_')}"
  end

  # convert a PST/PDT time to UTC as a JavaScript integer
  def timestamp(time)
    date = @file[/(\w+ \d+, \d+)/]
    ASF::Board::TIMEZONE.parse("#{date} #{time}").to_i * 1000
  end
end

require_relative 'agenda/front'
require_relative 'agenda/minutes'
require_relative 'agenda/exec-officer'
require_relative 'agenda/attachments'
require_relative 'agenda/committee'
require_relative 'agenda/special'
require_relative 'agenda/discussion'
require_relative 'agenda/back'
require_relative 'agenda/summary'
