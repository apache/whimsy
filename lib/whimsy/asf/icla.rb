module ASF

  class ICLA
    attr_accessor :id, :legal_name, :name, :email

    @@mtime = nil

    OFFICERS = ASF::SVN['private/foundation/officers']
    SOURCE = "#{OFFICERS}/iclas.txt" if OFFICERS

    # flush caches if source file changed
    def self.refresh
      if SOURCE and File.mtime(SOURCE) != @@mtime
        @@mtime = File.mtime(SOURCE)
        @@id_index = nil
        @@email_index = nil
        @@name_index = nil

        @@availids = nil
      end
    end

    # load ICLA information for every committer
    def self.preload
      refresh
      each do |icla|
        ASF::Person.find(icla.id).icla =  icla unless icla.id == 'notinaval'
      end
    end

    # find ICLA by ID
    def self.find_by_id(value)
      return if value == 'notinavail'

      refresh
      unless @@id_index
        @@id_index = {}
        each {|icla| @@id_index[icla.id] = icla}
      end

      @@id_index[value]
    end

    # find ICLA by email
    def self.find_by_email(value)
      refresh
      unless @@email_index
        @@email_index = {}
        each {|icla| @@email_index[icla.email.downcase] = icla}
      end

      @@email_index[value.downcase]
    end

    # find ICLA by name
    def self.find_by_name(value)
      refresh
      unless @@name_index
        @@name_index = {}
        each {|icla| @@name_index[icla.name] = icla}
      end

      @@email_index[value]
    end

    # list of all ids
    def self.availids
      refresh
      return @@availids if @@availids
      availids = []
      each {|icla| availids << icla.id unless icla.id == 'notinavail'}
      @availids = availids
    end

    # iterate over all of the ICLAs
    def self.each(&block)
      if @@id_index and not @@id_index.empty?
        @@id_index.values.each(&block)
      elsif @@email_index and not @@email_index.empty?
        @@email_index.values.each(&block)
      elsif @@name_index and not @@name_index.empty?
        @@name_index.values.each(&block)
      elsif File.exist?(SOURCE)
        File.read(SOURCE).scan(/^([-\w]+):(.*?):(.*?):(.*?):/).each do |list|
          icla = ICLA.new()
          icla.id = list[0]
          icla.legal_name = list[1]
          icla.name = list[2]
          icla.email = list[3]
          block.call(icla)
        end
      end
    end

    # sort support

    def self.asciize(name)
      if name.match /[^\x00-\x7F]/
        # digraphs.  May be culturally sensitive
        name.gsub! /\u00df/, 'ss'
        name.gsub! /\u00e4|a\u0308/, 'ae'
        name.gsub! /\u00e5|a\u030a/, 'aa'
        name.gsub! /\u00e6/, 'ae'
        name.gsub! /\u00f1|n\u0303/, 'ny'
        name.gsub! /\u00f6|o\u0308/, 'oe'
        name.gsub! /\u00fc|u\u0308/, 'ue'

        # latin 1
        name.gsub! /[\u00e0-\u00e5]/, 'a'
        name.gsub! /\u00e7/, 'c'
        name.gsub! /[\u00e8-\u00eb]/, 'e'
        name.gsub! /[\u00ec-\u00ef]/, 'i'
        name.gsub! /[\u00f2-\u00f6]|\u00f8/, 'o'
        name.gsub! /[\u00f9-\u00fc]/, 'u'
        name.gsub! /[\u00fd\u00ff]/, 'y'

        # Latin Extended-A
        name.gsub! /[\u0100-\u0105]/, 'a'
        name.gsub! /[\u0106-\u010d]/, 'c'
        name.gsub! /[\u010e-\u0111]/, 'd'
        name.gsub! /[\u0112-\u011b]/, 'e'
        name.gsub! /[\u011c-\u0123]/, 'g'
        name.gsub! /[\u0124-\u0127]/, 'h'
        name.gsub! /[\u0128-\u0131]/, 'i'
        name.gsub! /[\u0132-\u0133]/, 'ij'
        name.gsub! /[\u0134-\u0135]/, 'j'
        name.gsub! /[\u0136-\u0138]/, 'k'
        name.gsub! /[\u0139-\u0142]/, 'l'
        name.gsub! /[\u0143-\u014b]/, 'n'
        name.gsub! /[\u014C-\u0151]/, 'o'
        name.gsub! /[\u0152-\u0153]/, 'oe'
        name.gsub! /[\u0154-\u0159]/, 'r'
        name.gsub! /[\u015a-\u0162]/, 's'
        name.gsub! /[\u0162-\u0167]/, 't'
        name.gsub! /[\u0168-\u0173]/, 'u'
        name.gsub! /[\u0174-\u0175]/, 'w'
        name.gsub! /[\u0176-\u0178]/, 'y'
        name.gsub! /[\u0179-\u017e]/, 'z'

        # denormalized diacritics
        name.gsub! /[\u0300-\u036f]/, ''
      end

      name.gsub /[^\w]+/, '-'
    end

    SUFFIXES = /^([Jj][Rr]\.?|I{2,3}|I?V|VI{1,3}|[A-Z]\.)$/

    # rearrange line in an order suitable for sorting
    def self.lname(line)
      return '' if line.start_with? '#'
      id, name, rest = line.split(':',3)
      return '' unless name

      # Drop trailing (comment string) or /* comment */
      name.sub! /\(.+\)$/,''
      name.sub! /\/\*.+\*\/$/,''
      return '' if name.strip.empty?

      name = name.split.reverse
      suffix = (name.shift if name.first =~ SUFFIXES)
      suffix += ' ' + name.shift if name.first =~ SUFFIXES
      name << name.shift
      name << name.shift if name.first=='Lewis' and name.last=='Ship'
      name << name.shift if name.first=='Gallardo' and name.last=='Rivera'
      name << name.shift if name.first=="S\u00e1nchez" and name.last=='Vega'
      # name << name.shift if name.first=='van'
      name.last.sub! /^IJ/, 'Ij'
      name.unshift(suffix) if suffix
      name.map! {|word| asciize(word)}
      name = name.reverse.join(' ')

      "#{name}:#{rest}"
    end

    # sort an entire iclas.txt file
    def self.sort(source)
      headers = source.scan(/^#.*/)
      lines = source.scan(/^\w.*/)

      headers.join("\n") + "\n" + 
        lines.sort_by {|line| lname(line + "\n")}.join("\n") + "\n"
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
      @icla || ICLA.availids.include?(name)
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
