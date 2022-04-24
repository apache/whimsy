require 'yaml'
require 'net/http'
module ASF

  # Represents a Petri culture
  # currently defined in
  # https://petri.apache.org/info.yaml

  PETRI_INFO = 'https://petri.apache.org/info.yaml'
  class Petri
    include Enumerable

    attr_reader :id
    attr_reader :name
    attr_reader :description
    attr_reader :status
    attr_reader :mentors
    attr_reader :website
    attr_reader :mailinglists
    attr_reader :repository
    attr_reader :issues
    attr_reader :wiki
    attr_reader :release
    attr_reader :licensing

    def initialize(entry)
      key, hash = entry
      @id = key
      hash.each { |name, value| instance_variable_set("@#{name}", value) }
    end

    # Array of all Petri culture entries
    def self.list
      @list = []
      response = Net::HTTP.get_response(URI(PETRI_INFO))
      response.value() # Raises error if not OK
      yaml = YAML.safe_load(response.body, permitted_classes: [Symbol])
      # @mentors = yaml['mentors']
      yaml['cultures'].each do |proj|
        @list << new(proj)
      end
      @list
    end
  end
end

if __FILE__ == $0
  ASF::Petri.list.each do |e|
    p e
    p e.website
  end
end