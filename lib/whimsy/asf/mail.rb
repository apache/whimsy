require 'weakref'

module ASF

  class Mail
    # return a Hash containing complete list of all known emails, and the
    # ASF::Person that is associated with that email.
    def self.list
      begin
        return Hash[@list.to_a] if @list
      rescue NoMethodError, WeakRef::RefError
      end

      list = Hash.new

      # load info from LDAP
      people = ASF::Person.preload(['mail', 'asf-altEmail'])
      people.each do |person|
        (person.mail+person.alt_email).each do |mail|
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
        next if icla.id == 'notinavail'
        list["#{icla.id.downcase}@apache.org"] ||= person
      end

      @list = WeakRef.new(list)
      list
    end

    # Parse the .archives file to get the list names
    def self._load_lists
      apmail_bin = ASF::SVN['infra/infrastructure/apmail/trunk/bin']
      file = File.join(apmail_bin, '.archives')
      if not @lists or File.mtime(file) != @list_mtime
        lists = Hash[File.read(file).scan(
          /^\s+"(\w[-\w]+)", "\/home\/apmail\/(public|private)-arch\//
        )]
        # Drop the infra test lists
        lists.delete_if {|list| list =~ /-infra-[a-z]$/ or list == 'incubator-infra-dev' }
        @lists = lists
        @list_mtime = File.mtime(file)
      end
    end

    # get a list of all mailing lists.  If <tt>public_private</tt> is
    # <tt>false</tt> this will be a simple list.  If <tt>public_private</tt> is
    # <tt>true</tt>, return a Hash where the values are either <tt>public</tt>
    # or <tt>private</tt>.
    def self.lists(public_private=false)
      Mail._load_lists
      public_private ? @lists : @lists.keys
    end

    # which lists are available for subscription via Whimsy?
    def self.cansub(member, pmc_chair)
      Mail._load_lists
      if member
          lists = @lists.keys
          # These are not subscribable via Whimsy
          lists.delete_if {|list| list =~ /^(ea|secretary|president|treasurer|chairman|committers|pmc-chairs)$/ }
          lists.delete_if {|list| list =~ /(^|-)security$|^security(-|$)/ }
          lists
      else
          whitelist = ['infra-users', 'jobs', 'site-dev', 'committers-cvs', 'site-cvs', 'concom', 'party']
          # Can always subscribe to public lists and the whitelist
          lists = @lists.keys.select{|key| @lists[key] == 'public' or whitelist.include? key}
          # Chairs need the board lists
          if pmc_chair
            lists += ['board', 'board-commits', 'board-chat']
          end
          lists
      end
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
        options = Hash[sendmail.map {|key, value| [key.to_sym, value.untaint]}]

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
  end

  class Person < Base
    # find a Person by email address
    def self.find_by_email(value)
      value.downcase!

      person = Mail.list[value]
      return person if person
    end

    # List of inactive email addresses: currently only contains the address in
    # <tt>iclas.txt</tt> if it is not contained in the list of active email
    # addresses.
    def obsolete_emails
      return @obsolete_emails if @obsolete_emails
      result = []
      if icla
        unless active_emails.any? {|mail| mail.downcase == icla.email.downcase}
          result << icla.email
        end
      end
      @obsolete_emails = result
    end

    # Active emails: primary email address, alt email addresses, and 
    # member email addresses.
    def active_emails
      (mail + alt_email + member_emails).uniq
    end

    # All known email addresses: includes active, obsolete, and apache.org
    # email addresses.
    def all_mail
      (active_emails + obsolete_emails + ["#{id}@apache.org"]).uniq
    end
  end

  class Committee
    # mailing list for this committee.  Generally returns the first name in
    # the dns (e.g. whimsical).  If so, it can be prefixed by a number of
    # list names (e.g. dev, private) and <tt>.apache.org</tt> is to be
    # appended.  In some cases, the name contains an <tt>@</tt> sign and
    # is the fill name for the mail list.
    def mail_list
      case name.downcase
      when 'comdev'
        'community'
      when 'httpcomponents'
        'hc'
      when 'whimsy'
        'whimsical'

      when 'brand management'
        'trademarks@apache.org'
      when 'executive assistant'
        'ea@apache.org'
      when 'legal affairs'
        'legal-internal@apache.org'
      when 'marketing and publicity'
        'press@apache.org'
      when 'tac'
        'travel-assistance@apache.org'
      when 'w3c relations'
        'w3c@apache.org'
      else
        name
      end
    end
  end

  class Podling
    # base name used in constructing mailing list name.
    def mail_list
      name
    end
  end

end
