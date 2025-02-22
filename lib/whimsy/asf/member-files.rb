$LOAD_PATH.unshift '/srv/whimsy/lib' if __FILE__ == $PROGRAM_NAME

require 'whimsy/asf/string-utils'

require_relative 'config'
require_relative 'ldap'
require_relative 'svn'

module ASF

  class MemberFiles

    NOMINATED_MEMBERS = 'nominated-members.txt'
    NOMINATED_BOARD = 'board_nominations.txt'
    BOARD_BALLOT = 'board_ballot'
    BOARD_BALLOT_EXT = '.txt'
    NAME2OUTPUTKEY = { # names (from Regex) and corresponding output keys
      'email' => 'Nominee email',
      'nomby' => 'Nominated by',
      'seconds' => 'Seconded by',
      'statement' => 'Nomination Statement',
    }

    # Same as MEMBER_REGEX, but no <uid> and no <email>
    BOARD_REGEX = %r{
        \A(?<header>(?<name>[^:]+?):?)\r?\n
        \s*Nominated\ by[:]?\s*(?<nomby>.*)\r?\n
        \s*Seconded\ by[:]?\s*(?<seconds>.*?)\r?\n+
        \s*Nomination\ [sS]tatement[:]?\s*?\r?\n+(?<statement>.*)\z
        }mx

    # This Regex is very similar to the one in the script used to create ballots:
    # https://svn.apache.org/repos/private/foundation/Meetings/steve-tools/seed-issues.py
    MEMBER_REGEX = %r{
      \A(?<header>(?:(?<uid>[-_.a-z0-9]+)\s+)?(?<name>[^:]+?):?)\r?\n
      \s*Nominee\ email[:]?\s*(?<email>.*)\r?\n
      \s*Nominated\ by[:]?\s*(?<nomby>.*)\r?\n
      \s*Seconded\ by[:]?\s*(?<seconds>.*?)\r?\n+
      \s*Nomination\ [sS]tatement[:]?\s*?\r?\n+(?<statement>.*)\z
      }mx

    SECONDS_SEPARATOR = '    *** Statements by Seconds (below; please include your id) ***'

    # section dividers in nomination files
    MEMBER_DIVIDER = "-----------------------------------------\n"
    BOARD_DIVIDER  = "---------------------------------------\n"

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
      case name
      when NOMINATED_BOARD
        regex = BOARD_REGEX
      when NOMINATED_MEMBERS
        regex = MEMBER_REGEX
      else
        raise ArgumentError.new "Unexpected name: #{name}"
      end
      # N.B. The format has changed over the years. This is the syntax as of 2021.
      # -----------------------------------------
      # <empty line>
      #  header line
      #    Nominee email: (not present in board file)
      #    Nominated by:
      #    Seconded by:

      #    Nomination Statement:

      # Find most recent file:
      nomfile = latest_meeting(name)

      lastheader = nil # what was the last valid header
      # It does not appear to be possible to have file open or read
      # automatically transcode strings, so we do it here.
      # This is necessary to avoid issues with matching Regexes.
      File.open(nomfile, mode: 'rb:UTF-8')
        .map(&:scrub)
        .slice_before(/^\s*-{35,60}\s*/)
        .drop(2) # instructions and sample block
        .each do |block|
        block.shift(1) # divider
        nominee = {}
        header = nil
        data = block.join.strip
        next if data == ''
        md = regex.match(data)
        raise  ArgumentError.new "Cannot parse #{data}" unless md
        md.named_captures.each do |k, v|
          case k
          when 'header'
            header = v.strip
          when 'uid', 'name'
            # not currently used
          else
            outkey = NAME2OUTPUTKEY[k]
            raise ArgumentError.new "Unexpected regex capture name: #{k}" if outkey.nil?
            v = v.split("\n") if k == 'statement' or k == 'seconds'
            nominee[outkey] = v
          end
        end
        yield header, nominee
      end
    end

    # create a member nomination entry in the standard format
    #
    def self.make_member_nomination(fields = {})
      availid = fields[:availid] or raise ArgumentError.new(':availid is required')
      publicname = ASF::Person[availid]&.cn or raise ArgumentError.new(":availid #{availid} is invalid")
      nomby = fields[:nomby] or raise ArgumentError.new(':nomby is required')
      ASF::Person[nomby]&.dn or raise ArgumentError.new(':nomby is invalid')
      secby = fields[:secby] || ''
      statement = fields[:statement] or raise ArgumentError.new(':statement is required')
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
        '',
        SECONDS_SEPARATOR,
        ''
      ].compact.join("\n") + "\n"
    end

    # create a board nomination entry in the standard format
    #
    def self.make_board_nomination(fields = {})
      availid = fields[:availid] or raise ArgumentError.new(':availid is required')
      publicname = ASF::Person[availid]&.cn or raise ArgumentError.new(":availid #{availid} is invalid")
      nomby = fields[:nomby] or raise ArgumentError.new(':nomby is required')
      ASF::Person[nomby]&.dn or raise ArgumentError.new(':nomby is invalid')
      secby = fields[:secby] || ''
      statement = fields[:statement] or raise ArgumentError.new(':statement is required')
      [
        '',
        "   #{publicname}",
        "   Nominated by: #{nomby}@apache.org",
        "   Seconded by: #{secby}",
        '',
        '   Nomination Statement:',
        ASFString.reflow(statement, 4, 80),
        '',
        SECONDS_SEPARATOR,
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
          # Allow for multiple n/a ids
          raise ArgumentError.new("Duplicate id: #{id}") if ids.include? id and id != 'n/a'
          ids[id] = 1
          m[2].split.last
        else
          'ZZ'
        end
      end
      # reconstitute the file
      [header, sections, ''].join(MEMBER_DIVIDER)
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
      [header, sections, ''].join(BOARD_DIVIDER)
    end

    # update the member nominees
    def self.update_member_nominees(env, wunderbar, entries=nil, msg=nil, opt={})
      nomfile = latest_meeting(NOMINATED_MEMBERS)
      opt[:diff] = true unless opt.include? :diff # default to true
      ASF::SVN.update(nomfile, msg || 'Updating nominated members', env, wunderbar, opt) do |_tmpdir, contents|
        sort_member_nominees(contents, entries)
      end
    end

    # create a single director ballot statement (if not present)
    # @param availid of director nominee
    def self.add_board_ballot(env, wunderbar, availid, msg=nil, opt={})
      bdir = File.join(latest_meeting(), BOARD_BALLOT)
      bfile = File.join(bdir, "#{availid}#{BOARD_BALLOT_EXT}")
      ASF::SVN.update(bfile, msg || "Adding board_ballot template for #{$availid}", env, wunderbar, opt) do |_tmpdir, contents|
        "Instructions: ../runbook/director_ballot_email.txt #{contents}" # Add instructions as single line
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
      na = 0 # Allow for noms without ids
      ASF::MemberFiles.parse_file(NOMINATED_MEMBERS) do |hdr, nominee|
        # for members, the header currently looks like this:
        # availid <PUBLIC NAME>
        # In the past, it has had other layouts, for example:
        # availid PUBLIC NAME
        # PUBLIC NAME <email address>:
        id, name = hdr.split(' ', 2)
        if id == 'n/a' # Ensure multiple n/a entries can exist
          na += 1
          id = "n/a_#{na}"
        end
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
      # Remove informational entry if somehow present
      nominees.delete('<<Nominee Name>>')
      return nominees
    end

    # Return hash of board nomination statements
    # TODO Annotate with board nominees data?
    def self.board_statements
      statements = {}
      Dir["#{File.join(latest_meeting(), BOARD_BALLOT)}/*#{BOARD_BALLOT_EXT}"].each do |f|
        statements[File.basename(f, BOARD_BALLOT_EXT)] = {'candidate_statement' => IO.readlines(f)}
      end
      return statements
    end

    # Merged board nominations and statements
    def self.board_all
      noms = board_nominees
      stats = board_statements
      combined = {}
      noms.each do |availid, hash|
        combined[availid] = hash.merge(stats.fetch(availid, {}))
        combined[availid]['Nomination Statement'] = combined[availid]['Nomination Statement'].join('\n')
        combined[availid]['nombyemail'] = combined[availid].fetch('Nominated by', '')
        combined[availid]['nombyeavailid'] = combined[availid]['nombyemail'].sub('@apache.org', '')
        person = ASF::Person.find(combined[availid]['nombyeavailid'])
        combined[availid]['nombycn'] = person.public_name
      end
      return combined
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
  puts '--------------'
  ASF::MemberFiles.board_nominees.each do |k, v|
    p [k,
       v['Public Name'],
       v['Public Name']&.encoding,
       v['Public Name']&.valid_encoding?]
  end
end
