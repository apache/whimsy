require 'nokogiri'
require_relative '../asf'

module ASF
  class Podlings
    include Enumerable

    def each
      incubator_content = ASF::SVN['asf/incubator/public/trunk/content']
      podlings = Nokogiri::XML(File.read("#{incubator_content}/podlings.xml"))
      podlings.search('podling').map do |node|
        data = {
          name: node['name'],
          status: node['status'],
          description: node.at('description').text,
          mentors: node.search('mentor').map {|mentor| mentor['username']}
        }
        data[:champion] = node.at('champion')['availid'] if node.at('champion')
        yield node['resource'], data
      end
    end
  end
end
