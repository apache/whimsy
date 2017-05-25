# Map non-ASCII characters to lower case ASCII
def asciize(name)
  if name =~ /[^\x00-\x7F]/
    # digraphs.  May be culturally sensitive
    name.gsub! /\u00df/, 'ss'
    name.gsub! /\u00e4|a\u0308/, 'ae'
    name.gsub! /\u00e5|a\u030a/, 'aa'
    name.gsub! /\u00e6/, 'ae'
    name.gsub! /\u00f1|n\u0303/, 'ny'
    name.gsub! /\u00f6|o\u0308/, 'oe'
    name.gsub! /\u00fc|u\u0308/, 'ue'

    # latin 1 - uppercase
    name.gsub! /[\u00c0-\u00c5]/, 'a'
    name.gsub! /\u00c7/, 'c'
    name.gsub! /[\u00c8-\u00cb]/, 'e'
    name.gsub! /[\u00cc-\u00cf]/, 'i'
    name.gsub! /[\u00d2-\u00d6]|\u00d8/, 'o'
    name.gsub! /[\u00d9-\u00dc]/, 'u'
    name.gsub! /[\u00dd]/, 'y'

    # latin 1 - lowercase
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

  return name
end
