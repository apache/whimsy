$LOAD_PATH.unshift '/srv/whimsy/lib' if __FILE__ == $PROGRAM_NAME

require 'whimsy/asf/string-utils'

require_relative 'config'
require_relative 'ldap'
require_relative 'svn'

module ASF

  class MemberFiles

    NOMINATED_MEMBERS = 'nominated-members.txt'
    NOMINATED_BOARD = 'board_nominations.txt'
    # N.B. Board does not include email
    VALID_KEYS = ['Nominated by','Nomination Statement', 'Nominee email', 'Seconded by']
  
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
            .slice_before(/^ +(\w+ \w+):\s*/) # split on the header names
            .each_with_index do |para, idx|
          if idx == 0 # id and name (or just name for board)
            header = para.first.strip
          else
            key, value = para.shift.strip.split(':', 2)
            unless VALID_KEYS.include? key
              raise ArgumentError.new "Invalid key name '#{key}' at '#{header}' in #{nomfile}"
            end
            if para.size == 0 # no more data to follow
              nominee[key] = value
            else
              tmp = [value, para.map(&:chomp)].flatten.compact
              tmp.pop if tmp[-1].empty? # drop trailing empty line only
              nominee[key] = tmp
            end
          end
        end

        unless header.nil? || header.empty?
          keys = nominee.keys
          case name
          when NOMINATED_BOARD
            raise ArgumentError.new "Expected 3 keys, found #{keys} at '#{header}' in #{name}" unless keys.size == 3
          when NOMINATED_MEMBERS
            raise ArgumentError.new "Expected 4 keys, found #{keys} at '#{header}' in #{name}" unless keys.size == 4
          end
          yield header, nominee 
        end
      end
    end

    # create a member nomination entry in the standard format
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
        '   Nomination Statement:',
        ASFString.reflow(statement, 4, 80),
        ''
      ].compact.join("\n") + "\n"
    end

    # create a board nomination entry in the standard format
    #
    def self.make_board_nomination(fields = {})
      availid = fields[:availid] or raise ArgumentError.new(":availid is required")
      publicname = ASF::Person[availid]&.cn or raise ArgumentError.new(":availid #{availid} is invalid")
      nomby = fields[:nomby] or raise ArgumentError.new(":nomby is required")
      ASF::Person[nomby]&.dn or raise ArgumentError.new(":nomby is invalid")
      secby = fields[:secby] || ''
      statement = fields[:statement] or raise ArgumentError.new(":statement is required")
      [
        '',
        "   #{publicname}",
        "   Nominated by: #{nomby}@apache.org",
        "   Seconded by: #{secby}",
        '',
        '   Nomination Statement:',
        ASFString.reflow(statement, 4, 80),
        ''
      ].compact.join("\n") + "\n"
    end

    # Sort the member_nominees, optionally adding new entries
    def self.sort_member_nominees(contents, entries=nil)
      sections = contents.split(%r{^-{10,}\n})
      header = sections.shift(2)
      sections.append(*entries) if entries # add new entries if any
      ids = {}
      sections.sort_by! do |s|
        # sort by last name; check for duplicates
        m = s.match %r{(\S+) +<([^>]+)>}
        if m
          id = m[1]
          raise ArgumentError.new("Duplicate id: #{id}") if ids.include? id
          ids[id] = 1
          m[2].split.last
        else
          'ZZ'
        end
      end
      # reconstitute the file
      [header, sections, ''].join("-----------------------------------------\n")
    end

    # Sort the board_nominees, optionally adding new entries
    def self.sort_board_nominees(contents, entries=nil)
      sections = contents.split(%r{^-{10,}\n})
      header = sections.shift(2)
      sections.pop if sections.last.strip == ''
      sections.append(*entries) if entries # add new entries if any
      names = {}
      # replace 'each' by 'sort_by!' to sort by last name
      sections.each do |s|
        # sort by last name; check for duplicates
        m = s.match %r{\s+(.+)}
        if m
          name = m[1]
          raise ArgumentError.new("Duplicate id: #{name}") if names.include? name
          names[name] = 1
          name.split.last
        else
          'ZZ'
        end
      end
      # reconstitute the file
      [header, sections, ''].join("---------------------------------------\n")
    end

    # update the member nominees
    def self.update_member_nominees(env, wunderbar, entries=nil, msg=nil, opt={})
      nomfile = latest_meeting(NOMINATED_MEMBERS)
      opt[:diff] = true unless opt.include? :diff # default to true
      ASF::SVN.update(nomfile, msg || 'Updating nominated members', env, wunderbar, opt) do |_tmpdir, contents|
        sort_member_nominees(contents, entries)
      end
    end

    # update the board nominees
    def self.update_board_nominees(env, wunderbar, entries=nil, msg=nil, opt={})
      nomfile = latest_meeting(NOMINATED_BOARD)
      opt[:diff] = true unless opt.include? :diff # default to true
      ASF::SVN.update(nomfile, msg || 'Updating board nominations', env, wunderbar, opt) do |_tmpdir, contents|
        sort_board_nominees(contents, entries)
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
      ASF::MemberFiles.parse_file(NOMINATED_BOARD) do |hdr, nominee|
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
