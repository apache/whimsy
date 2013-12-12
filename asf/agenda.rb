module ASF
  module Board
  end
end

class ASF::Board::Agenda
  @@parsers = []
  def self.parse(file=nil, &block)
    @@parsers << block if block
    new.parse(file)  if file
  end

  def initialize
    @sections = {}
  end

  def scan(text, pattern, &block)
    text.scan(pattern).each do |matches|
      hash = Hash[pattern.names.zip(matches)]
      yield hash if block

      section = hash.delete('section')
      section ||= hash.delete('attach')

      if section
        hash['approved'] &&= hash['approved'].strip.split(/[ ,]+/)

        @sections[section] ||= {}
        @sections[section].merge!(hash)
      end
    end
  end

  def parse(file)
    @file = file
    @@parsers.each { |parser| instance_exec(&parser) }

    result = @sections.map do |section, hash|
      hash[:attach] = section
      hash
    end

    result.to_a
  end
end

require_relative 'agenda/front'
require_relative 'agenda/minutes'
require_relative 'agenda/exec-officer'
require_relative 'agenda/attachments'
require_relative 'agenda/committee'
require_relative 'agenda/special'
require_relative 'agenda/back'
