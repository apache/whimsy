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
    OFFICERS = ASF::SVN.find('private/foundation/officers')

    # location of the iclas.txt file; may be <tt>nil</tt> if not found.
    SOURCE = OFFICERS ? "#{OFFICERS}/iclas.txt" : nil

    # flush caches if source file changed
    def self.refresh
      if not SOURCE or File.mtime(SOURCE) != @@mtime
        @@mtime = SOURCE ? File.mtime(SOURCE) : Time.now
        @@id_index = nil
        @@email_index = nil
        @@name_index = nil
        @@svn_change = nil

        @@availids = nil
      end
    end

    # Date and time of the last change in <tt>iclas.txt</tt> in the working copy
    def self.svn_change
      self.refresh
      if SOURCE
        @@svn_change ||= Time.parse(
          `svn info #{SOURCE}`[/Last Changed Date: (.*) \(/, 1]).gmtime
      end
    end

    # load ICLA information for every committer
    def self.preload
      people = []
      each do |icla|
        unless icla.id == 'notinaval'
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
      if @@id_index and not @@id_index.empty?
        @@id_index.values.each(&block)
      elsif @@email_index and not @@email_index.empty?
        @@email_index.values.each(&block)
      elsif @@name_index and not @@name_index.empty?
        @@name_index.values.each(&block)
      elsif SOURCE and File.exist?(SOURCE)
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
        end
      end
    end

    # rearrange line in an order suitable for sorting
    def self.lname(line)
      return '' if line.start_with? '#'
      id, name, rest = line.split(':',3)
      return '' unless name

      # Drop trailing (comment string) or /* comment */
      name.sub! /\(.+\)$/,''
      name.sub! /\/\*.+\*\/$/,''
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

    # list of reserved availids
    def self.availids_reserved
      return @@availids_reserved if @@availids_reserved
      archive = ASF::SVN['private/foundation/officers']
      reserved = File.read("#{archive}/reserved-ids.yml").scan(/^- (\S+)/).flatten.uniq
      @@availids_reserved = reserved
    end

    # list of all availids that are are taken or reserved
    def self.availids_taken()
      self.availids_reserved + self.availids
    end

    # is the availid taken (in use or reserved)?
    def self.taken?(id)
      puts(id)
      return self.availids_reserved.include?(id) ||
             self.availids.include?(id)
    end

    # is the id available?
    def self.available?(id)
      return ! self.taken?(id)
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
    archive = ASF::SVN['private/foundation/officers/historic']
    name = JSON.parse(File.read("#{archive}/committers.json"))[id]
    name = id if name and name.empty?
    name
  end
end
