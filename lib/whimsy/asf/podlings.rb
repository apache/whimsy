require 'nokogiri'
require_relative '../asf'

module ASF
  class Podlings
    include Enumerable

    def quarter
      [
        Date.today.strftime('%B'),
        Date.today.next_month.strftime('%B'),
        Date.today.next_month.next_month.strftime('%B')
      ]
    end

    def each
      incubator_content = ASF::SVN['asf/incubator/public/trunk/content']
      podlings = Nokogiri::XML(File.read("#{incubator_content}/podlings.xml"))
      podlings.search('podling').map do |node|

        reporting = node.at('reporting')
        if reporting
          group = reporting['group']
          monthly = reporting.text.split(/,\s*/) if reporting['monthly']
          reporting = %w(January April July October) if group == '1'
          reporting = %w(February May August November) if group == '2'
          reporting = %w(March June September December) if group == '3'
          reporting.rotate! until quarter.include? reporting.first

          if monthly
            monthly.shift until monthly.empty? or quarter.include? monthly.first
            reporting = (monthly + reporting).uniq
          end
        end

        data = {
          name: node['name'],
          status: node['status'],
          reporting: reporting,
          description: node.at('description').text,
          mentors: node.search('mentor').map {|mentor| mentor['username']}
        }
        data[:champion] = node.at('champion')['availid'] if node.at('champion')
        yield node['resource'], data
      end
    end

    # convenience method for iterating over the entire list
    def self.to_enum
      self.new.to_enum    
    end

    # return the entire list as a hash
    def self.list
      Hash[self.new.to_a]
    end
  end
end
