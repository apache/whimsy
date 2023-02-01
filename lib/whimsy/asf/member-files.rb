require 'whimsy/asf/string-utils'

require_relative 'config'
require_relative 'ldap'
require_relative 'svn'

module ASF

  class MemberFiles

    NOMINATED_MEMBERS = 'nominated-members.txt'

    # get the latest meeting directory or nomination file
    def self.latest_meeting(name=nil)
      if name.nil? # we want the parent directory
        name = NOMINATED_MEMBERS # ensure the target directory has been set up
        File.dirname(Dir[File.join(ASF::SVN['Meetings'], '[2-9][0-9]*', name)].max)
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

    # create a nomination entry in the standard format
    #
    def self.make_member_nomination(fields = {})
      availid = fields[:availid] or raise ArgumentError.new(":availid is required")
      publicname = ASF::Person[availid]&.cn or raise ArgumentError.new(":availid #{availid} is invalid")
      nomby = fields[:nomby] or raise ArgumentError.new(":nomby is required")
      ASF::Person[nomby]&.dn or raise ArgumentError.new(":nomby is invalid")
      secby = fields[:secby] || ''
      statement = fields[:statement] or raise ArgumentError.new(":statement is required")
      [
        '',
        " #{availid} <#{publicname}>",
        '',
        "   Nominee email: #{availid}@apache.org",
        "   Nominated by: #{nomby}@apache.org",
        "   Seconded by: #{secby}",
        '',
        '   Nomination statement:',
        statement.asf_reflow(4, 80),
        ''
      ].compact.join("\n") + "\n"
    end

    # Sort the member_nominees, optionally adding new entries
    def self.sort_member_nominees(contents, entries=nil)
      # Find most recent file:
      sections = contents.split(%r{^-{10,}\n})
      header = sections.shift(2)
      sections.append(*entries) if entries # add new entries if any
      sections.sort_by! do |s|
        # sort by last name
        (s[%r{\S+ +<([^>]+)>}, 1] || 'ZZ').split.last
      end
      # reconstitute the file
      [header, sections, ''].join("-----------------------------------------\n")
    end

    # update the member nominees
    def self.update_member_nominees(env, wunderbar, entries=nil, msg=nil, opt={})
      nomfile = latest_meeting(NOMINATED_MEMBERS)
      ASF::SVN.update(nomfile, msg || 'Updating nominated members', env, wunderbar, opt) do |_tmpdir, contents|
        sort_member_nominees(contents, entries)
      end
    end

    # TODO: change to return arrays rather than hash.
    # This would help detect duplicate entries

    # Return hash of member nominees
    def self.member_nominees
      nominees = {}
      ASF::MemberFiles.parse_file(NOMINATED_MEMBERS) do |hdr, nominee|
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
