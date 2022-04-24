require_relative 'person/override-dates'

module ASF

  #
  # An instance of this class represents a person.  Data comes from a variety
  # of sources: LDAP, <tt>asf--authorization-template</tt>, <tt>iclas.txt</tt>,
  # <tt>members.txt</tt>, <tt>nominated-members.txt</tt>, and
  # <tt>potential-member-watch-list.txt</tt>.

  class Person
    # sort support

    # Convert non-ASCII characters to equivalent ASCII
    # optionally: replace any remaining non-word characters (e.g. '.' and space) with '-'
    def self.asciize(name, nonWord = '-')
      if name.match %r{[^\x00-\x7F]} # at least one non-ASCII character present
        # digraphs.  May be culturally sensitive
        # Note that the combining accents require matching two characters
        name.gsub! %r{\u00df}, 'ss'
        name.gsub! %r{\u00e4|a\u0308}, 'ae' # 308 = combining diaeresis
        name.gsub! %r{\u00e5|a\u030a}, 'aa' # a with ring above: should this translate as 'a'?
        name.gsub! %r{\u00c5|A\u030a}, 'AA' # A with ring above: should this translate as 'A'?
        name.gsub! %r{\u00e6},         'ae' # small letter ae
        name.gsub! %r{\u00c6},         'AE' # large letter AE
        name.gsub! %r{\u00f1|n\u0303}, 'ny' # 303 = combining tilde
        name.gsub! %r{\u00d1|N\u0303}, 'NY' # 303 = combining tilde
        name.gsub! %r{\u00f6|o\u0308}, 'oe' # 308 = combining diaeresis
        name.gsub! %r{\u00d6|O\u0308}, 'OE' # 308 = combining diaeresis
        name.gsub! %r{\u00de},         'TH' # thorn
        name.gsub! %r{\u00fe},         'th' # thorn
        name.gsub! %r{\u00fc|u\u0308}, 'ue' # 308 = combining diaeresis
        name.gsub! %r{\u00dc|U\u0308}, 'UE' # 308 = combining diaeresis

        # latin 1
        name.gsub! %r{[\u00e0-\u00e3]}, 'a' # a with various accents
        name.gsub! %r{[\u00c0-\u00c3]}, 'A' # A with various accents
        name.gsub! %r{\u00e7},          'c' # c-cedilla
        name.gsub! %r{\u00c7},          'C' # C-cedilla
        name.gsub! %r{\u00f0},          'd' # eth
        name.gsub! %r{\u00d0},          'D' # eth
        name.gsub! %r{[\u00e8-\u00eb]}, 'e'
        name.gsub! %r{[\u00c8-\u00cb]}, 'E'
        name.gsub! %r{[\u00ec-\u00ef]}, 'i'
        name.gsub! %r{[\u00cc-\u00cf]}, 'I'
        name.gsub! %r{[\u00f2-\u00f5\u00f8]}, 'o'
        name.gsub! %r{[\u00d2-\u00d5\u00d8]}, 'O'
        name.gsub! %r{[\u00f9-\u00fb]}, 'u'
        name.gsub! %r{[\u00d9-\u00db]}, 'U'
        name.gsub! %r{[\u00fd\u00ff]},  'y'
        name.gsub! %r{[\u00dd\u0178]},  'Y'

        # Latin Extended-A
        name.gsub! %r{[\u0100\u0102\u0104]}, 'A'
        name.gsub! %r{[\u0101\u0103\u0105]}, 'a'
        name.gsub! %r{[\u0106\u0108\u010A\u010C]}, 'C'
        name.gsub! %r{[\u0107\u0109\u010B\u010D]}, 'c'
        name.gsub! %r{[\u010E\u0110]}, 'D'
        name.gsub! %r{[\u010F\u0111]}, 'd'
        name.gsub! %r{[\u0112\u0114\u0116\u0118\u011A]}, 'E'
        name.gsub! %r{[\u0113\u0115\u0117\u0119\u011B]}, 'e'
        name.gsub! %r{[\u014A]}, 'ENG'
        name.gsub! %r{[\u014B]}, 'eng'
        name.gsub! %r{[\u011C\u011E\u0120\u0122]}, 'G'
        name.gsub! %r{[\u011D\u011F\u0121\u0123]}, 'g'
        name.gsub! %r{[\u0124\u0126]}, 'H'
        name.gsub! %r{[\u0125\u0127]}, 'h'
        name.gsub! %r{[\u0128\u012A\u012C\u012E\u0130]}, 'I'
        name.gsub! %r{[\u0129\u012B\u012D\u012F\u0131]}, 'i'
        name.gsub! %r{[\u0132]}, 'IJ'
        name.gsub! %r{[\u0133]}, 'ij'
        name.gsub! %r{[\u0134]}, 'J'
        name.gsub! %r{[\u0135]}, 'j'
        name.gsub! %r{[\u0136]}, 'K'
        name.gsub! %r{[\u0137]}, 'k'
        name.gsub! %r{[\u0138]}, 'kra'
        name.gsub! %r{[\u0139\u013B\u013D\u013F\u0141]}, 'L'
        name.gsub! %r{[\u013A\u013C\u013E\u0140\u0142]}, 'l'
        name.gsub! %r{[\u0143\u0145\u0147]}, 'N'
        name.gsub! %r{[\u0144\u0146\u0148\u0149]}, 'n'
        name.gsub! %r{[\u014C\u014E\u0150]}, 'O'
        name.gsub! %r{[\u014D\u014F\u0151]}, 'o'
        name.gsub! %r{[\u0152]}, 'OE'
        name.gsub! %r{[\u0153]}, 'oe'
        name.gsub! %r{[\u0154\u0156\u0158]}, 'R'
        name.gsub! %r{[\u0155\u0157\u0159]}, 'r'
        name.gsub! %r{[\u015A\u015C\u015E\u0160]}, 'S'
        name.gsub! %r{[\u015B\u015D\u015F\u0161]}, 's'
        name.gsub! %r{[\u0162\u0164\u0166]}, 'T'
        name.gsub! %r{[\u0163\u0165\u0167]}, 't'
        name.gsub! %r{[\u0168\u016A\u016C\u016E\u0170\u0172]}, 'U'
        name.gsub! %r{[\u0169\u016B\u016D\u016F\u0171\u0173]}, 'u'
        name.gsub! %r{[\u0174]}, 'W'
        name.gsub! %r{[\u0175]}, 'w'
        name.gsub! %r{[\u0176\u0178]}, 'Y'
        name.gsub! %r{[\u0177]}, 'y'
        name.gsub! %r{[\u0179\u017B\u017D]}, 'Z'
        name.gsub! %r{[\u017A\u017C\u017E]}, 'z'

        # Latin Extended Additional
        # N.B. Only ones seen in iclas.txt are included here
        name.gsub! %r{\u1ea0},          'A' # A with combining dot below
        name.gsub! %r{\u1ea1},          'a' # a with combining dot below
        name.gsub! %r{\u1ec4},          'E' # E with circumflex and tilde
        name.gsub! %r{\u1ec5},          'e' # e with circumflex and tilde

        # remove unhandled combining diacritics (some combinations are handled above)
        name.gsub! %r{[\u0300-\u036f]}, ''
      end

      if nonWord
        # deal with any remaining non-word characters
        name.strip.gsub %r{[^\w]+}, nonWord if nonWord
      else
        name
      end
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
      name.last.sub! %r{^IJ}, 'Ij'
      name.unshift(suffix) if suffix
      name.map! {|word| asciize(word)}
      name.reverse.join(' ').downcase
    end

    # surname prefixes
    SINGLE_PFX = %w(von van Van de De del Del den le Le O Di Du dos St.)
    DOUBLE_PFX = ['de la', 'van der', 'van de', 'van den', 'von der']
    # parse a name into LDAP fields
    def self.ldap_name(name)
      words = name.gsub(',', '').split(' ')
      result = {'cn' => name}
      result['title'] = words.shift if words.first == 'Dr.' or words.first == 'Dr'
      result['initials'] = []
      while words.first =~ %r{^[A-Z]\.$}
        result['initials'] << words.shift
      end
      if words.last =~ /^Ph\.D\.?/
        title = words.pop # Always pop (||= short-circuits the pop)
        result['title'] ||= title
      end
      result['generationQualifier'] = words.pop if words.last =~ SUFFIXES
      result['givenName'] = words.shift if words.size > 1 # don't use remaining word as it must be sn
      # TODO givenName can have multiple entries
      # extract surnames like van Gogh etc
      if words.size >= 3 and DOUBLE_PFX.include? words[-3..-2].join(' ')
        result['sn'] = words[-3..-1].join(' ')
        result['unused'] = words[0..-4]
      elsif words.size >= 2 and SINGLE_PFX.include? words[-2]
        result['sn'] = words[-2..-1].join(' ')
        result['unused'] = words[0..-3]
      else
        result['sn'] = words.pop
        result['unused'] = words
      end
      result
    end

    # extract sn and givenName from cn (needed for LDAP entries)
    # returns sn, [givenName,...]
    # Note that givenName is returned as an array (may be empty).
    # This is because givenName is an optional attribute which may appear multiple times.
    # It remains to be seen whether we want to create multiple attributes,
    # or whether it is more appropriate to add at most one attribute
    # containing all the givenName values. [The array can be joined to produce a single value].
    # DRAFT version: not for general use yet
    # Does not handle multi-word family names or honorifics etc
    def self.ldap_parse_cn_DRAFT(cn, familyFirst)
      words = cn.split(' ')
      if familyFirst
        sn = words.shift
      else
        sn = words.pop
      end
      return sn, words
    end

    # Name equivalences
    names = [
      %w(Alex Alexander Alexandru),
      %w(Andrew Andy),
      %w(William Bill),
      %w(Chris Christopher Christoph),
      %w(Joe Joey),
      %w(Dan Daniel),
      %w(David Dave),
      %w(Don Donald),
      %w(Greg Gregory),
      %w(Jim James),
      %w(Matt Matthew),
      %w(Mike Michael Mick),
      %w(Nikoloai Nickolay),
      %w(Phil Philip),
      %w(Rob Robbie Robert),
      %w(Stephen Steve Steven),
      %w(Tom Thomas),
      %w(Tomek Tomasz),
      %w(Zach Zachary),
    ]
    NAMEHASH = Hash.new
    names.each_with_index do |list, index|
      list.each do |name|
        NAMEHASH[name] = index
      end
    end
    def self.names_equivalent?(one, two)
      # index cannot be -1, cannot match if missing entries are set to -1 or nil
      return one == two ||
        (NAMEHASH[one] || -1) == NAMEHASH[two] ||
        one.start_with?("#{two} ") || two.start_with?("#{one} ") ||
        (NAMEHASH[one.split(' ').first] || -1) == NAMEHASH[two.split(' ').first]
    end

    # DRAFT
    # return name suitable for a filename stem
    # Should normally be applied to the legal name
    def self.stem_DRAFT(name)
      # need to split before
      name = name.gsub(',', ' ').split(/ +/).map {|n| n.gsub(%r{^(Dr|Jr|Sr|[A-Z])\.$}, '\1')}
      asciize(name.join('-')).downcase.chomp('-')
    end

    # return public name in a sortable order (last name first)
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

    def createDate
      createTimestamp[0..7]
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
    # _either_ LDAP or <tt>members.txt</tt>.  Note: LDAP includes
    # infrastructure staff members that may not be ASF Members.
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
