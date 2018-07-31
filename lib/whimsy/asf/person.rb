require_relative 'person/override-dates.rb'

module ASF

  #
  # An instance of this class represents a person.  Data comes from a variety
  # of sources: LDAP, <tt>asf--authorization-template</tt>, <tt>iclas.txt</tt>,
  # <tt>members.txt</tt>, <tt>nominated-members.txt</tt>, and
  # <tt>potential-member-watch-list.txt</tt>.

  class Person
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
        name.gsub! /\u00c9/, 'e'
        name.gsub! /\u00d3/, 'o'
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

      name.strip.gsub /[^\w]+/, '-'
    end

    # generational suffixes
    SUFFIXES = /^([Jj][Rr]\.?|I{2,3}|I?V|VI{1,3}|[A-Z]\.)$/

    # rearrange line in an order suitable for sorting
    def self.sortable_name(name)
      name = name.split.reverse
      suffix = (name.shift if name.first =~ SUFFIXES)
      suffix += ' ' + name.shift if name.first =~ SUFFIXES
      name << name.shift
      # name << name.shift if name.first=='van'
      name.last.sub! /^IJ/, 'Ij'
      name.unshift(suffix) if suffix
      name.map! {|word| asciize(word)}
      name.reverse.join(' ').downcase
    end

    # parse a name into LDAP fields
    def self.ldap_name(name)
      words = name.gsub(',', '').split(' ')
      result = {'cn' => name}
      result['title'] = words.shift if words.first == 'Dr.' or words.first == 'Dr'
      if words.last =~ /^Ph\.D\.?/
        title = words.pop # Always pop (||= short-circuits the pop)
        result['title'] ||= title
      end 
      result['generationQualifier'] = words.pop if words.last =~ SUFFIXES
      result['givenName'] = words.shift # TODO does gn allow multiple words?
      # extract surnames like van Gogh etc
      if words.size >= 3 and words[-3..-2] == %w(de la) or words[-3..-2] == %w(van der) or words[-3..-2] == %w(van de) or words[-3..-2] == %w(van den)
        result['sn'] = words[-3..-1].join(' ')
        result['unused'] = words[0..-4]
      elsif words.size >= 2 and %w(von van Van de De del Del den le Le O).include?  words[-2]
        result['sn'] = words[-2..-1].join(' ')
        result['unused'] = words[0..-3]
      else
        result['sn'] = words.pop
        result['unused'] = words
      end 
      result
    end

    # return name in a sortable order (last name first)
    def sortable_name
      Person.sortable_name(self.public_name)
    end

    # determine account creation date.  Notes:
    # *  LDAP info is not accurate for dates prior to 2009.  See
    #    person/override-dates.rb
    # *  createTimestamp isn't loaded by default (but can either be preloaded
    #    or fetched explicitly)
    def createTimestamp
      result = @@create_date[name] 
      result ||= attrs['createTimestamp'][0] rescue nil # in case not loaded
      result ||= ASF.search_one(base, "uid=#{name}", 'createTimestamp')[0][0]
      result
    end

    # return person's public name, searching a variety of sources, starting
    # with iclas.txt, then LDAP, and finally the archives.
    def public_name
      return icla.name if icla
      cn = [attrs['cn']].flatten.first
      cn.force_encoding('utf-8') if cn.respond_to? :force_encoding
      return cn if cn
      ASF.search_archive_by_id(name)
    end

    # Returns <tt>true</tt> if this person is listed as an ASF member in
    # _either_ LDAP or <tt>members.txt</tt>.
    def asf_member?
      ASF::Member.status[name] or ASF.members.include? self
    end

    # Returns <tt>true</tt> if this person is listed as an ASF member in
    # _either_ LDAP or <tt>members.txt</tt> or this person is listed as
    # an PMC chair in LDAP.
    def asf_officer_or_member?
      asf_member? or ASF.pmc_chairs.include? self
    end
  end
end
