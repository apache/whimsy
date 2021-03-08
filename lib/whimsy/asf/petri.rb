require 'yaml'
require_relative 'git'

module ASF

  # Represents a Petri culture
  # currently defined only in 
  # https://github.com/apache/petri/blob/master/info.yaml

  # Initial very basic implementation.

  PETRI_INFO = '/apache/petri/master/info.yaml'

  class Petri
    include Enumerable

    attr_reader :name

    attr_reader  :description

    def initialize(entry)
      @name = entry # currently only the name is provided
    end

    # Array of all Petri culture entries
    def self.list
      @list = []
      yaml = YAML.safe_load(ASF::Git.github(PETRI_INFO))
      # @mentors = yaml['mentors']
      yaml['projects'].each do |proj|
        @list << new(proj)
      end
      @list
    end
  end
end

if __FILE__ == $0
  ASF::Petri.list.each do |e|
    p e.name
  end
end