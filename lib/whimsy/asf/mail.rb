##   Licensed to the Apache Software Foundation (ASF) under one or more
##   contributor license agreements.  See the NOTICE file distributed with
##   this work for additional information regarding copyright ownership.
##   The ASF licenses this file to You under the Apache License, Version 2.0
##   (the "License"); you may not use this file except in compliance with
##   the License.  You may obtain a copy of the License at
## 
##       http://www.apache.org/licenses/LICENSE-2.0
## 
##   Unless required by applicable law or agreed to in writing, software
##   distributed under the License is distributed on an "AS IS" BASIS,
##   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
##   See the License for the specific language governing permissions and
##   limitations under the License.

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
      apmail_bin = ASF::SVN['apmail_bin']
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

    def self.list_mtime
      Mail._load_lists
      @list_mtime
    end

    # list of mailing lists that aren't actively seeking new subscribers
    def self.deprecated
      apmail_bin = ASF::SVN['apmail_bin']
      YAML.load_file(File.join(apmail_bin, 'deprecated_mailing_lists.yml'))
    end

    # which lists are available for subscription via Whimsy?
    # member: true if member
    # pmc_chair: true if pmc_chair
    # ldap_pmcs: list of (P)PMC mail_list names
    def self.cansub(member, pmc_chair, ldap_pmcs)
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

          # (P)PMC members need their private lists
          if ldap_pmcs
            # ensure that the lists actually exist
            lists += ldap_pmcs.map {|lp| "#{lp}-private"}.select{|l| @lists.keys.include? l}
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

    # Convert list name to form used in bin/.archives
    def self.archivelistid(dom,list)
      return "apachecon-#{list}" if dom == 'apachecon.com'
      return list if dom == 'apache.org'
      dom.sub(".apache.org",'-') + list
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
        return email if name.length == 0 || dom.length == 0
        dom.downcase!
        dom = 'gmail.com' if dom == 'googlemail.com' # same mailbox
        if dom == 'gmail.com'
          return name.sub(/\+.*/,'').gsub('.','').downcase + '@' + dom
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
        'legal-internal@apache.org'
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
      else
        name
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
        name
      end
    end
  end

end
