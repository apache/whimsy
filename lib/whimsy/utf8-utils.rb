#!/usr/bin/env ruby

# Utility module for working with UTF8
# Initially only contains a method to repair UTF8 files

module UTF8Utils
  UTF8_REPLACE = '�'

  #
  # Initially assumes the file is in utf8-softbank encoding
  # If that does not work, then it tries ISO-8859-1
  def self.repair(src, dst, verbose=false)
    opts = {undef: :replace, invalid: :replace}
    ec1 = Encoding::Converter.new('utf8-softbank', 'UTF-8', **opts)
    ec2 = Encoding::Converter.new('iso-8859-1', 'UTF-8', **opts)

    open(dst,'w:utf-8') do |w|
      open(src,'rb').each do |l|
        o = ec1.convert(l) # initial conversion try
        unless o == l
          if o.include? UTF8_REPLACE # something did not convert
            o = ec2.convert(l) # try another encoding
          end
          if verbose
            puts l
            puts o
            puts ''
          end
        end
        w.write o
      end
    end
  end
end
