require_relative 'config'
require_relative 'svn'
module ASF

  class MemberFiles

    # Return a hash of nominated members.
    # key: availid
    # value: hash of entries:
    # keys:
    # Public Name
    # Nominee email
    # Nominated by
    # Seconded by => array of seconders      
    # Nomination Statement => array of text lines
    def self.member_nominees
      # N.B. The format has changed over the years. This is the syntax as of 2021.
      # -----------------------------------------
      # <empty line>
      #  <NOMINATED PERSON'S APACHE ID> <PUBLIC NAME>
      #    Nominee email:
      #    Nominated by:
      #    Seconded by:
      
      #    Nomination Statement:
      
      # Find most recent file:
      nomfile = Dir[File.join(ASF::SVN['Meetings'], '*', 'nominated-members.txt')].max

      nominees = {}
      # options = {:external_encoding => Encoding::BINARY}
      options = {:external_encoding => Encoding::BINARY,
                 :internal_encoding => Encoding::UTF_8,
                 :invalid => :replace}
      # N.B. the ** prefix is needed to avoid the following message:
      # Warning: Using the last argument as keyword parameters is deprecated 
      File.open(nomfile, mode='r', **options)
          .slice_before(/^\s*---+--\s*/)
          .drop(2) # instructions and sample block
          .each do |block|
        nominee = {}
        id = nil
        block.shift(2) # divider and blank line
        block
            .slice_before(/^ +(\S+ \S+):\s*/) # split on the header names
            .each_with_index do |para, idx|
          if idx == 0 # id and name
            id, nominee['Public Name'] = para.first.chomp.split(' ',2)
          else
            key, value = para.shift.strip.split(': ',2)
            if para.size == 0 # no more data to follow
              nominee[key] = value
            else
              tmp = [value,para.map(&:chomp)].flatten.compact
              tmp.pop if tmp[-1].empty? # drop trailing empty line only
              nominee[key] = tmp
            end
          end
        end
        if id
          nominees[id] = nominee if id
        else
          unless block.join('') =~ /^\s+$/ # all blank, e.g. trailing divider
            Wunderbar.warn "Error, could not find public name"
            Wunderbar.warn block.inspect
            nominees['notinavail'] = {'Public Name' => '-- WARNING: unable to parse section --'}
          end
        end
      end
      nominees
    end
  end
end

if __FILE__ == $0
  ASF::MemberFiles.member_nominees.each {|k,v| p [k, v['Public Name']]}
end