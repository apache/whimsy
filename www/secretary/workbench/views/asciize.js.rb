# Convert non-ASCII characters to equivalent ASCII
# optionally: replace any remaining non-word characters (e.g. '.' and space) with '-'
def asciize(name, nonWord = '-')
  # Should agree with ASF::Person.asciize
  if name =~ /[^\x00-\x7F]/  # at least one non-ASCII character present
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
    name.gsub! %r{[\u014D\u014F\u0151\u01A1]}, 'o'
    name.gsub! %r{[\u0152]}, 'OE'
    name.gsub! %r{[\u0153]}, 'oe'
    name.gsub! %r{[\u0154\u0156\u0158]}, 'R'
    name.gsub! %r{[\u0155\u0157\u0159]}, 'r'
    name.gsub! %r{[\u015A\u015C\u015E\u0160]}, 'S'
    name.gsub! %r{[\u015B\u015D\u015F\u0161]}, 's'
    name.gsub! %r{[\u0162\u0164\u0166]}, 'T'
    name.gsub! %r{[\u0163\u0165\u0167]}, 't'
    name.gsub! %r{[\u0168\u016A\u016C\u016E\u0170\u0172]}, 'U'
    name.gsub! %r{[\u0169\u016B\u016D\u016F\u0171\u0173\u01B0]}, 'u'
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
    return name.strip.gsub %r{[^\w]+}, nonWord if nonWord
  end
  return name
end
