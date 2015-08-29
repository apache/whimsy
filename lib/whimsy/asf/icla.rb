module ASF

  class ICLA
    include Enumerable
    ICLA_Struct = Struct.new(:id, :legal_name, :name, :email)

    def self.preload
      new.each do |id, legal_name, name, email|
        if id != 'notinaval'
          ASF::Person.find(id).icla = 
            ICLA_Struct.new(id, legal_name, name, email)
        end 
      end
    end

    def self.find_by_id(value)
      return if value == 'notinavail'
      new.each do |id, legal_name, name, email|
        if id == value
          return ICLA_Struct.new(id, legal_name, name, email)
        end 
      end
      nil
    end

    def self.find_by_email(value)
      value = value.downcase
      new.each do |id, legal_name, name, email|
        if email.downcase == value
          return ICLA_Struct.new(id, legal_name, name, email)
        end 
      end
      nil
    end

    def self.availids
      return @availids if @availids
      availids = []
      new.each do |id, legal_name, name, email| 
        availids << id unless id == 'notinavail'
      end
      @availids = availids
    end

    def each(&block)
      officers = ASF::SVN['private/foundation/officers']
      if officers and File.exist?("#{officers}/iclas.txt")
        iclas = File.read("#{officers}/iclas.txt")
        iclas.scan(/^([-\w]+):(.*?):(.*?):(.*?):/).each(&block)
      end
    end
  end

  class Person
    def icla
      @icla ||= ASF::ICLA.find_by_id(name)
    end

    def icla=(icla)
      @icla = icla
    end

    def icla?
      ICLA.availids.include? name
    end
  end

  # Search archive for historical records of people who were committers
  # but never submitted an ICLA (some of which are still ASF members or
  # members of a PMC).
  def self.search_archive_by_id(value)
    require 'net/http'
    require 'nokogiri'
    historical_committers = 'http://people.apache.org/~rubys/committers.html'
    doc = Nokogiri::HTML(Net::HTTP.get(URI.parse(historical_committers)))
    doc.search('tr').each do |tr|
      tds = tr.search('td')
      next unless tds.length == 3
      return tds[1].text if tds[0].text == value
    end
    nil
  rescue
    nil
  end
end
