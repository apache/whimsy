require 'weakref'

module ASF

  class Mail
    # return a Hash containing complete list of all known emails, and the
    # ASF::Person that is associated with that email.
    def self.list
      begin
        return @list.to_h if @list
      rescue NoMethodError, WeakRef::RefError
      end

      list = {}

      # load info from LDAP
      people = ASF::Person.preload(['mail', 'asf-altEmail'])
      people.each do |person|
        (person.mail + person.alt_email).each do |mail|
          list[mail.downcase] = person
        end
      end

      # load all member emails in one pass
      ASF::Member.each do |id, text|
        Member.emails(text).each do |mail|
          list[mail.downcase] ||= Person.find(id)
        end
      end

      # load all ICLA emails in one pass
      ASF::ICLA.each do |icla|
        person = Person.find(icla.id)
        list[icla.email.downcase] ||= person
        next if icla.noId?

        list["#{icla.id.downcase}@apache.org"] ||= person
      end

      @list = WeakRef.new(list)
      list
    end

    # list of mailing lists that aren't actively seeking new subscribers
    def self._deprecated
      self._load_auto()
      @auto[:deprecated]
    end

    def self._cannot_sub
      self._load_auto()
      @auto[:disallowed] + @auto[:intrinsic]
    end

    def self._cannot_unsub
      self._load_auto()
      @auto[:intrinsic]
    end

    def self._committers_allowed
      self._load_auto()
      @auto[:committers]
    end

    def self._chairs_allowed
      self._load_auto()
      @auto[:chairs]
    end

    def self._members_allowed
      self._load_auto()
      @auto[:members] + @auto[:chairs]
    end

    # Is a list available for unsubscription via Whimsy?
    # Params: listid (a@b)
    # Return: true or false
    def self.unsubbable?(listid)
      !self._cannot_unsub.include? listid
    end

    # which lists are available for subscription via Whimsy?
    # Params:
    # member: true if member
    # pmc_chair: true if pmc_chair
    # ldap_pmcs: list of (P)PMC mail_list names to which the user belongs
    # lid_only: return lid instead of [dom,list,lid]
    # Return: an array of entries: lid or [dom,list,lid]
    def self.cansub(member, pmc_chair, ldap_pmcs, lidonly = true)
      allowed = []
      parse_flags do |dom, list, f|
        autoid = _autosubid(dom, list)
        next if self._deprecated.include? autoid
        next if self._cannot_sub.include? autoid
        lid = archivelistid(dom, list)

        cansub = false
        modsub = isModSub?(f)
        if not modsub # subs not moderated; allow all
          cansub = true
        elsif self._committers_allowed().include?(autoid) # always allowed
          cansub = true
        else # subs are moderated
          if member
            if list == 'private' or self._members_allowed.include?(autoid)
              cansub = true
            end
          elsif ldap_pmcs and list == 'private' and ldap_pmcs.include? dom.sub('.apache.org', '')
            cansub = true
          end
          if pmc_chair and self._chairs_allowed.include? autoid
            cansub = true
          end
        end
        if cansub
          if lidonly
            allowed << lid
          else
            allowed << [dom, list, lid]
          end
        end
      end
      allowed
    end

    # which lists are available for automatic moderation via Whimsy?
    # Params:
    # ldap_pmcs: list of (P)PMC mail_list names to which the user belongs (as owner)
    # lid_only: return lid instead of [dom,list,lid]
    # Return: an array of entries: lid or [dom,list,lid]
    def self.canmod(ldap_pmcs, lidonly = true)
      allowed = []
      parse_flags do |dom, list, _|
        autoid = _autosubid(dom, list)
        next if self._deprecated.include? autoid
        next if self._cannot_sub.include? autoid
        lid = archivelistid(dom, list)

        if ldap_pmcs.include? dom.sub('.apache.org', '')
          if lidonly
            allowed << lid
          else
            allowed << [dom, list, lid]
          end
        end
      end
      allowed
    end

    # common configuration for sending mail; loads <tt>:sendmail</tt>
    # configuration from <tt>~/.whimsy</tt> if available; otherwise default
    # to disable openssl verification as that is what it required in order
    # to work on the infrastructure provided whimsy-vm.
    def self.configure
      # fetch overrides
      sendmail = ASF::Config.get(:sendmail)

      if sendmail
        # convert string keys to symbols
        options = Hash[sendmail.map {|key, value| [key.to_sym, value]}]

        # extract delivery method
        method = options.delete(:delivery_method).to_sym
      else
        # provide defaults that work on whimsy-vm* infrastructure.  Since
        # procmail is configured with a self-signed certificate, verification
        # isn't a possibility
        method = :smtp
        options = {openssl_verify_mode: 'none'}
      end

      ::Mail.defaults do
        delivery_method method, options
      end
    end

    # List of .qmail files that could clash with user ids (See: INFRA-14566)
    def self.qmail_ids
      return [] unless File.exist? '/srv/subscriptions/qmail.ids'

      File.read('/srv/subscriptions/qmail.ids').split
    end

    # Is the id used by qmail?
    # See also ASF::ICLA.taken?
    def self.taken?(id)
      self.qmail_ids.include? id
    end

    # Convert list@host.apache.org to host-list (listkey) style
    def self.listdom2listkey(listdom)
      list, dom = listdom.split('@')
      self.archivelistid(dom, list)
    end

    # Convert dom, list to form currently used in subreq.py
    def self.archivelistid(dom, list)
      return "apachecon-#{list}" if dom == 'apachecon.com'
      return list if dom == 'apache.org'

      dom.sub(".apache.org", '-') + list
    end

    # Convert dom, list to form used in mail_list_autosub.yml
    # This changed in March 2022 from dom-list format
    def self._autosubid(dom, list)
      return "#{list}@#{dom}"
    end

    # Canonicalise an email address, removing aliases and ignored punctuation
    # and downcasing the name if safe to do so
    #
    # Currently only handles aliases for @gmail.com and @googlemail.com
    #
    # All domains are converted to lower-case
    #
    # The case of the name part is preserved since some providers may be case-sensitive
    # Almost all providers ignore case in names, however that is not guaranteed
    def self.to_canonical(email)
      parts = email.split('@')
      if parts.length == 2
        name, dom = parts
        return email if name.empty? || dom.empty?

        dom.downcase!
        dom = 'gmail.com' if dom == 'googlemail.com' # same mailbox
        if dom == 'gmail.com'
          return name.sub(/\+.*/, '').gsub('.', '').downcase + '@' + dom
        else
          # Effectively the same:
          dom = 'apache.org' if dom == 'minotaur.apache.org'
          # only downcase the domain (done above)
          return name + '@' + dom
        end
      end
      # Invalid; return input rather than failing
      return email
    end

    private

    # Load the auto-subscription file
    def self._load_auto
      apmail_bin = ASF::SVN['apmail_bin']
      auto_file = File.join(apmail_bin, 'mail_list_autosub.yml')
      auto_mtime = File.mtime(auto_file) # fetch this up front in case file updated during loading
      if not @auto or auto_mtime != @auto_mtime
        @auto = YAML.load_file(auto_file)
        @auto_mtime = auto_mtime
      end
    end

    # Load the flags file
    def self._load_flags
      # flags for each mailing list
      @list_flags ||= File.join(ASF::Config[:subscriptions], 'list-flags')
      if not @flags or File.mtime(@list_flags) != @flags_mtime
        lists = []
        File.open(@list_flags).each do |line|
          if line.match(/^F:-([a-zA-Z]{26}) (\S+) (\S+)/)
            flags, dom, list = $1, $2, $3
            next if list =~ /^infra-[a-z]$/ or (dom == 'incubator' and list == 'infra-dev')

            lists << [dom, list, flags]
          else
            raise "Unexpected flags: #{line}"
          end
        end
        @flags = lists
        @flags_mtime = File.mtime(@list_flags)
      end
    end

    # parse the flags
    # F:-aBcdeFgHiJklMnOpqrSTUVWXYz domain list
    # Input:
    # filter = RE to match against the flags, e.g. /s/ for subsmod
    # Output:
    # yields: domain, list, flags
    def self.parse_flags(filter=nil)
      self._load_flags()
      @flags.each do |d, l, f|
        next if filter and f !~ filter

        yield [d, l, f]
      end
    end

    # Do the flags indicate subscription moderation?
    def self.isModSub?(flags)
      flags.include? 's'
    end

  end

  class Person < Base
    # find a Person by email address
    def self.find_by_email(value)
      person = Mail.list[value.downcase]
      return person if person
    end

    # List of inactive email addresses: currently only contains the address in
    # <tt>iclas.txt</tt> if it is not contained in the list of active email
    # addresses.
    def obsolete_emails
      return @obsolete_emails if @obsolete_emails

      result = []
      if icla && active_emails.none? {|mail| mail.downcase == icla.email.downcase}
        result << icla.email
      end
      @obsolete_emails = result
    end

    # Active emails: primary email address, alt email addresses, and
    # member email addresses.
    def active_emails
      (mail + alt_email + member_emails).uniq
    end

    # All known email addresses: includes active, obsolete, and apache.org
    # email addresses. (But don't add notinavail@apache.org)
    def all_mail
      (active_emails + obsolete_emails + (id == 'notinavail' ? [] : ["#{id}@apache.org"])).uniq
    end
  end

  class Committee
    # mailing list for this committee.  Generally returns the first name in
    # the dns (e.g. whimsical).  If so, it can be prefixed by a number of
    # list names (e.g. dev, private) and <tt>.apache.org</tt> is to be
    # appended.  In some cases, the name contains an <tt>@</tt> sign and
    # is the full name for the mail list.
    def mail_list
      case name.downcase
      when 'comdev'
        'community'
      when 'httpcomponents'
        'hc'
      when 'whimsy'
        'whimsical'

      when 'brandmanagement'
        'trademarks@apache.org'
      when 'infrastructure'
        'infra'
      when 'dataprivacy'
        'privacy@apache.org'
      when 'legalaffairs'
        'legal-internal@apache.org'
      when 'fundraising'
        'fundraising-private@apache.org'
      when 'marketingandpublicity'
        'press@apache.org'
      when 'tac'
        'travel-assistance@apache.org'
      when 'w3crelations'
        'w3c@apache.org'
      when 'concom'
        'planners@apachecon.com'
      else
        name.downcase
      end
    end
  end

  class Podling
    # base name used in constructing mailing list name.
    def mail_list
      case name.downcase
      when 'odftoolkit'
        'odf'
      else
        name.downcase
      end
    end
  end

end
