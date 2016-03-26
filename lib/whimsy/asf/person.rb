#
# support for sorting of names
#

module ASF

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

    SUFFIXES = /^([Jj][Rr]\.?|I{2,3}|I?V|VI{1,3}|[A-Z]\.)$/

    # rearrange line in an order suitable for sorting
    def self.sortable_name(name)
      name = name.split.reverse
      suffix = (name.shift if name.first =~ SUFFIXES)
      suffix += ' ' + name.shift if name.first =~ SUFFIXES
      name << name.shift
#     name << name.shift if name.first=='Lewis' and name.last=='Ship'
      name << name.shift if name.first=='Gallardo' and name.last=='Rivera'
      name << name.shift if name.first=="S\u00e1nchez" and name.last=='Vega'
      # name << name.shift if name.first=='van'
      name.last.sub! /^IJ/, 'Ij'
      name.unshift(suffix) if suffix
      name.map! {|word| asciize(word)}
      name.reverse.join(' ')
    end

    def sortable_name
      Person.sortable_name(self.public_name)
    end
  end
end
