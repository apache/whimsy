require 'json'

module ASF

  #
  # Provide access to the contents of iclas.txt.
  #
  # N.B. only id and name should be considered public
  # form and claRef may contain details of the legal name beyond that in the public name
  class ICLA
    # availid of the ICLA, or <tt>notinavail</tt> if no id has been issued
    attr_accessor :id

    # legal name for the individual; should not be shared
    attr_accessor :legal_name

    # public name for the individual; should match LDAP
    attr_accessor :name

    # email address from the ICLA
    attr_accessor :email

    # lists the name of the form on file; includes claRef information
    attr_accessor :form

    # cla name or SVN revision info; extracted from the form
    attr_accessor :claRef

    @@mtime = nil

    # list of availids that should not be used
    @@availids_reserved = nil

    # location of a working copy of the officers directory in SVN
    OFFICERS = ASF::SVN.find('officers')

    # location of the iclas.txt file; may be <tt>nil</tt> if not found.
    SOURCE = OFFICERS ? File.join(OFFICERS, 'iclas.txt') : nil

    _officers_url = ASF::SVN.svnurl('officers') # not intended for external use

    SOURCE_URL = _officers_url ? File.join(_officers_url, 'iclas.txt') : nil

    # flush caches if source file changed
    def self.refresh
      if not SOURCE or File.mtime(SOURCE) != @@mtime
        @@mtime = SOURCE ? File.mtime(SOURCE) : Time.now
        @@id_index = nil
        @@email_index = nil
        @@name_index = nil
        @@icla_index = nil # cache of all iclas as an array
        @@svn_change = nil

        @@availids = nil
      end
    end

    # Date and time of the last change in <tt>iclas.txt</tt> in the working copy
    def self.svn_change
      self.refresh
      if SOURCE
        @@svn_change ||= Time.parse(ASF::SVN.getInfoItem(SOURCE, 'last-changed-date')).gmtime
      end
    end

    # load ICLA information for every committer
    def self.preload
      people = []
      each do |icla|
        unless icla.id == 'notinavail'
          person = ASF::Person.find(icla.id)
          people << person
          person.icla = icla
        end
      end
      people
    end

    # find ICLA by ID
    def self.find_by_id(value)
      return if value == 'notinavail' or not SOURCE

      refresh
      unless @@id_index
        @@id_index = {}
        each {|icla| @@id_index[icla.id] = icla}
      end

      @@id_index[value]
    end

    # find ICLA by email
    def self.find_by_email(value)
      return unless SOURCE

      refresh
      unless @@email_index
        @@email_index = {}
        each {|icla| @@email_index[icla.email.downcase] = icla}
      end

      @@email_index[value.downcase]
    end

    # find ICLA by name
    def self.find_by_name(value)
      return unless SOURCE
      refresh
      unless @@name_index
        @@name_index = {}
        each {|icla| @@name_index[icla.name] = icla}
      end

      @@name_index[value]
    end

    # find number of matches in target array
    def self.array_count_match(source, target)
      count = 0
      source.each {|src| count += 1 if target.include? src}
      count
    end

    # find close matches
    def self.find_matches(value)
      matches = []
      source = value.strip.downcase.split(' ')
      self.each do |icla|
        target = icla.legal_name.strip.downcase.split(' ')
        if target.sort == source.sort # order- and case-independent match
          matches << icla
        else
          cnt = self.array_count_match(source, target)
          if cnt >= 2
            matches << icla
          else
            cnt = self.array_count_match(target, source)
            if cnt >= 2
              matches << icla
            end
          end
        end
      end
      matches
    end

    # list of all ids
    def self.availids
      return [] unless SOURCE
      refresh
      return @@availids if @@availids
      availids = []
      each {|icla| availids << icla.id unless icla.id == 'notinavail'}
      @@availids = availids
    end

    # iterate over all of the ICLAs
    def self.each(&block)
      refresh
      if @@icla_index and not @@icla_index.empty?
        @@icla_index.each(&block)
      elsif SOURCE and File.exist?(SOURCE)
        @@icla_index = []
        File.read(SOURCE).scan(/^([-\w]+):(.*?):(.*?):(.*?):(.*)/).each do |list|
          icla = ICLA.new()
          icla.id = list[0]
          icla.legal_name = list[1]
          icla.name = list[2]
          icla.email = list[3]
          icla.form = list[4]
          match = icla.form.match(/^Signed CLA(?:;(\S+)| \((\+=.+)\))/)
          if match
            # match either the cla name or the SVN ref (+=...)
            icla.claRef = match[1] || match[2]
          end
          block.call(icla)
          @@icla_index << icla
        end
      end
    end

    # return a hash of unlisted ICLA names, keyed by email
    # if age > 0, return the entries added in the last n days
    def self.unlisted_name_by_email(age=0, env=nil)
      if age > 0
        rev = "{%s}:HEAD" % (Date.today - age)
        diff, _err = ASF::SVN.svn('diff', SOURCE_URL, {revision: rev, env: env})
        raise _err unless diff
        return Hash[*diff.scan(/^[+]notinavail:.*?:(.*?):(.*?):Signed CLA/).flatten.reverse]
      end
      hash = {}
      self.each { |icla| hash[icla.email] = icla.name if icla.noId? }
      hash
    end

    # show the original entry (reconstructed for now)
    def as_line
      [id, legal_name, name, email, form].join(':')
    end

    # rearrange line in an order suitable for sorting
    def self.lname(line)
      return '' if line.start_with? '#'
      _, name, rest = line.split(':', 3)
      return '' unless name

      # Drop trailing (comment string) or /* comment */
      name.sub!(/\(.+\)$/, '')
      name.sub!(/\/\*.+\*\/$/, '')
      return '' if name.strip.empty?

      name = ASF::Person.sortable_name(name)

      "#{name}:#{rest}"
    end

    # sort an entire <tt>iclas.txt</tt> file
    def self.sort(source)
      headers = source.scan(/^#.*/)
      lines = source.scan(/^\w.*/)

      headers.join("\n") + "\n" +
        lines.sort_by {|line| lname(line + "\n")}.join("\n") + "\n"
    end

    # list of mails rejected by badrcptto and badrcptto_patterns
    # Not intended for external use
    def self.badmails
      qmc = ASF::SVN['qmail_control']
      # non-patterns
      brt = File.join(qmc, 'badrcptto')
      badmails = File.read(brt).scan(/^(\w.+)@apache\.org\s*$/).flatten
      # now parse patterns
      brtpat = File.join(qmc, 'badrcptto_patterns')
      File.read(brtpat).each_line do |line|
        m = line.match(/^\^(\w.+)\\@/)
        if m
          badmails << m[1]
          next
        end
        # ^(abc|def|ghi)(jkl|mno|pqr)\@
        m = line.match(/^\^\(([|\w]+)\)\(([|\w]+)\)\\@/)
        if m
          m[1].split('|').each do |one|
            m[2].split('|').each do |two|
              badmails << "#{one}#{two}"
            end
          end
        else
          Wunderbar.warn "Error parsing #{brtpat} : could not match #{line}"
        end
      end
      badmails.uniq
    end

    # list of reserved availids
    def self.availids_reserved
      return @@availids_reserved if @@availids_reserved
      reserved = File.read(File.join(ASF::SVN['officers'], 'reserved-ids.yml')).scan(/^- (\S+)/).flatten.uniq
      # Add in badrcptto
      reserved += self.badmails
      @@availids_reserved = reserved.uniq
    end

    # list of all availids that are are taken or reserved
    # See also ASF::Mail.taken?
    def self.availids_taken
      self.availids_reserved + self.availids
    end

    # is the availid taken (in use or reserved)?
    # See also ASF::Mail.taken?
    def self.taken?(id)
      return self.availids_reserved.include?(id) ||
             self.availids.include?(id)
    end

    # is the id available?
    # See also ASF::Mail.taken?
    def self.available?(id)
      return !self.taken?(id)
    end

    # does the entry not have an id?
    def noId?
      self.id == 'notinavail'
    end
  end

  class Person
    # ASF::ICLA information for this person.
    def icla
      @icla ||= ASF::ICLA.find_by_id(name)
    end

    # setter for icla, should only be used by ASF::ICLA.preload
    def icla=(icla)
      @icla = icla
    end

    # does this individual have an ICLA on file?
    def icla?
      @icla || ICLA.availids.include?(name)
    end
  end

  # Search archive for historical records of people who were committers
  # but never submitted an ICLA (some of which are still ASF members or
  # members of a PMC).
  def self.search_archive_by_id(id)
    name = JSON.parse(File.read(File.join(ASF::SVN['officers_historic'], 'committers.json')))[id]
    name = id if name and name.empty?
    name
  end

end
