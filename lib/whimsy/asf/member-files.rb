require_relative 'config'
require_relative 'ldap'
require_relative 'svn'
module ASF

  class MemberFiles

    # get the latest meeting directory or nomination file
    def self.latest_meeting(name=nil)
      if name.nil? # we want the parent directory
        name = 'nominated-members.txt' # ensure the target directory has been set up
        File.dirname([File.join(ASF::SVN['Meetings'], '[2-9][0-9]*', name)].max)
      else
        Dir[File.join(ASF::SVN['Meetings'], '[2-9][0-9]*', name)].max
      end
    end

    # Return a hash of nominees.
    # key: availid (name for board nominees)
    # value: hash of entries:
    # keys:
    # Public Name
    # Nominee email
    # Nominated by
    # Seconded by => array of seconders
    # Nomination Statement => array of text lines
    def self.parse_file(name)
      # N.B. The format has changed over the years. This is the syntax as of 2021.
      # -----------------------------------------
      # <empty line>
      #  header line
      #    Nominee email:
      #    Nominated by:
      #    Seconded by:

      #    Nomination Statement:

      # Find most recent file:
      nomfile = latest_meeting(name)

      # It does not appear to be possible to have file open or read
      # automatically transcode strings, so we do it here.
      # This is necessary to avoid issues with matching Regexes.
      File.open(nomfile, mode: 'rb:UTF-8')
        .map(&:scrub)
        .slice_before(/^\s*---+--\s*/)
        .drop(2) # instructions and sample block
        .each do |block|
        block.shift(2) # divider and blank line
        nominee = {}
        header = nil
        block
            .slice_before(/^ +(\S+ \S+):\s*/) # split on the header names
            .each_with_index do |para, idx|
          if idx == 0 # id and name (or just name for board)
            header = para.first.strip
          else
            key, value = para.shift.strip.split(': ', 2)
            if para.size == 0 # no more data to follow
              nominee[key] = value
            else
              tmp = [value, para.map(&:chomp)].flatten.compact
              tmp.pop if tmp[-1].empty? # drop trailing empty line only
              nominee[key] = tmp
            end
          end
        end
        yield header, nominee unless header.nil? || header.empty?
      end
    end

    # TODO: change to return arrays rather than hash.
    # This would help detect duplicate entries

    # Return hash of member nominees
    def self.member_nominees
      nominees = {}
      ASF::MemberFiles.parse_file('nominated-members.txt') do |hdr, nominee|
        # for members, the header currently looks like this:
        # availid <PUBLIC NAME>
        # In the past, it has had other layouts, for example:
        # availid PUBLIC NAME
        # PUBLIC NAME <email address>:
        id, name = hdr.split(' ', 2)
        # remove the spurious <> wrapper
        nominee['Public Name'] = name.sub(%r{^<}, '').chomp('>')
        # TODO: handle missing availid better
        nominees[id] = nominee
      end
      nominees
    end

    # Return hash of board nominees
    def self.board_nominees
      nominees = {}
      ASF::MemberFiles.parse_file('board_nominations.txt') do |hdr, nominee|
        # for board, the header currently looks like this:
        # <PUBLIC NAME>
        id = ASF::Person.find_by_name!(hdr) || hdr # default to full name
        nominee['Public Name'] = hdr # the board file does not have ids
        nominees[id] = nominee
      end
      nominees
    end
  end
end

if __FILE__ == $0
  ASF::MemberFiles.member_nominees.each do |k, v|
    p [k,
       v['Public Name'],
       v['Public Name']&.encoding,
       v['Public Name']&.valid_encoding?]
  end
  puts "--------------"
  ASF::MemberFiles.board_nominees.each do |k, v|
    p [k,
       v['Public Name'],
       v['Public Name']&.encoding,
       v['Public Name']&.valid_encoding?]
  end
end
