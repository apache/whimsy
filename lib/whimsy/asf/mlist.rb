$LOAD_PATH.unshift '/srv/whimsy/lib'

require 'find'
require 'weakref'
require 'whimsy/asf/config'

module ASF

  module MLIST
    # utility methods for handling mailing list attributes:
    # - subscriptions
    # - moderation

    # whilst the source files are not particularly difficult to parse, it makes
    # sense to centralise access so any necessary changes can be localised

    # Note that email matching is case blind, but the original case is returned
    # list and domain names are always returned as lower-case

    # Potentially also the methods could check if access was allowed.
    # This is currently done by the callers

    # Note that the data files don't provide information on whether a list is
    # public or private.

    @@file_times  = {} # Key=type, value = modtime
    @@file_parsed = {} # Key=type, value = cache hash

    # Return an array of board subscribers followed by the file update time
    def self.board_subscribers(archivers=true)
      return list_filter('sub', 'apache.org', 'board', archivers), File.mtime(LIST_TIME)
    end

    # Return an array of members@ subscribers followed by the file update time
    def self.members_subscribers(archivers=true)
      return list_filter('sub', 'apache.org', 'members', archivers), File.mtime(LIST_TIME)
    end

    # Return an array of members-notify@ subscribers followed by the file update time
    def self.members_notify_subscribers(archivers=true)
      return list_filter('sub', 'apache.org', 'members-notify', archivers), File.mtime(LIST_TIME)
    end

    # Return an array of private@pmc subscribers followed by the file update time
    # By default does not return the standard archivers
    # pmc can either be a pmc name, in which case it uses private@<pmc>.apache.org
    # or it can be an ASF list name, e.g. w3c@apache.org
    def self.private_subscribers(pmc, archivers=false)
      return [] unless Dir.exist? LIST_BASE
      parts = pmc.split('@', 3) # want to detect trailing '@'
      if parts.length == 1
        return list_filter('sub', "#{pmc}.apache.org", 'private', archivers), File.mtime(LIST_TIME)
      elsif parts.length == 2 && parts[1] == 'apache.org'
        return list_filter('sub', parts[1], parts[0], archivers), File.mtime(LIST_TIME)
      else
        raise "Unexpected parameter: #{pmc}"
      end
    end

    def self.security_subscribers(pmc, archivers=false)
      return [] unless Dir.exist? LIST_BASE
      return list_filter('sub', "#{pmc}.apache.org", 'security', archivers), File.mtime(LIST_TIME)
    end

    # return a hash of subscriptions for the list of emails provided
    # the following keys are added to the response hash:
    # :subtime - the timestamp when the data was last updated
    # :subscriptions - an array of pairs: [list name, subscriber email]
    # N.B. not the same format as the moderates() method
    def self.subscriptions(emails, response = {})

      response[:subscriptions] = []
      response[:subtime] = File.mtime(LIST_TIME)

      emailslc = emails.map {|email| ASF::Mail.to_canonical(email.downcase)}
      list_parse('sub') do |dom, list, subs|
        subs.each do |sub|
          if emailslc.include? ASF::Mail.to_canonical(sub.downcase)
            response[:subscriptions] << ["#{list}@#{dom}", sub]
          end
        end
      end
      response
    end

    # return a hash of digest subscriptions for the list of emails provided
    # the following keys are added to the response hash:
    # :digtime - the timestamp when the data was last updated
    # :digests - an array of pairs: [list name, subscriber email]
    # N.B. not the same format as the moderates() method
    def self.digests(emails, response = {})

      response[:digests] = []
      response[:digtime] = File.mtime(LIST_TIME)

      emailslc = emails.map {|email| ASF::Mail.to_canonical(email.downcase)}
      list_parse('dig') do |dom, list, subs|
        subs.each do |sub|
          if emailslc.include? ASF::Mail.to_canonical(sub.downcase)
            response[:digests] << ["#{list}@#{dom}", sub]
          end
        end
      end
      response
    end

    # return the mailing lists which are moderated by any of the list of emails
    # the following keys are added to the response hash:
    # :modtime - the timestamp when the data was last updated
    # :moderates - a hash. key: list name; entry: array of emails that match a moderator for the list
    # N.B. not the same format as the subscriptions() method
    def self.moderates(user_emails, response = {})

      response[:moderates] = {}
      response[:modtime] = File.mtime(LIST_TIME)
      umails = user_emails.map {|m| ASF::Mail.to_canonical(m.downcase)} # outside loop
      list_parse('mod') do |dom, list, emails|
        matching = emails.select {|m| umails.include? ASF::Mail.to_canonical(m.downcase)}
        response[:moderates]["#{list}@#{dom}"] = matching unless matching.empty?
      end
      response
    end

    # helper function for matching against mod and subs entries
    # does the target mail_domain match the current list?
    def self.matches_list?(mail_domain, dom, list)
      # normal tlp style (now also podlings):
      #/home/apmail/lists/commons.apache.org/dev/mod
      #Apache lists (e.g. some non-PMCs)
      #/home/apmail/lists/apache.org/list/mod
      return "#{mail_domain}.apache.org" == dom ||
              (dom == 'apache.org' &&
              (list == mail_domain || list.start_with?("#{mail_domain}-"))
              ) || "#{list}@#{dom}" == mail_domain # e.g. planners@apachecon.com
    end

    # for a mail domain, extract related lists and their moderators
    # also returns the time when the data was last checked
    # If podling==true, then also check for old-style podling names
    # returns: [{dev@a.o=>[email1, email2]}, mod-time]
    # if mail_domain is nil, matches all lists except infra test lists
    def self.list_moderators(mail_domain, _podling=false)

      moderators = {}
      list_parse('mod') do |dom, list, subs|

        # drop infra test lists
        next if list =~ /^infra-[a-z]$/
        next if dom == 'incubator.apache.org' && list =~ /^infra-dev2?$/

        # does the list match our target?
        next unless mail_domain.nil? or matches_list?(mail_domain, dom, list)

        moderators["#{list}@#{dom}"] = subs.sort
      end
      return moderators.to_h, File.mtime(LIST_TIME)
    end

    # for a mail domain, extract related lists and their subscribers (default only the count)
    # also returns the time when the data was last checked
    # N.B. by default includes archivers as subscribers
    # For top-level apache.org lists, the mail_domain is either:
    # - the full list name (e.g. press), or:
    # - the list prefix (e.g. legal)
    # If podling==true, then also check for old-style podling names
    # If list_subs==true, return subscriber emails else sub count
    # If skip_archivers==true, exclude archivers
    # Matches:
    # {mail_domain}.apache.org/*
    # apache.org/{mail_domain}(-.*)? (e.g. press, legal)
    # incubator.apache.org/{mail_domain}-.* (if podling==true)
    # Returns: {list}@{dom}
    def self.list_subscribers(mail_domain, _podling=false, list_subs=false, skip_archivers=false)

      subscribers = {}
      list_parse('sub') do |dom, list, subs|

        # drop infra test lists
        next if list =~ /^infra-[a-z]$/
        next if dom == 'incubator.apache.org' && list =~ /^infra-dev2?$/

        # normal tlp style:
        #/home/apmail/lists/commons.apache.org/dev/mod

        # does the list match our target?
        next unless matches_list?(mail_domain, dom, list)

        if skip_archivers
          subscribers["#{list}@#{dom}"] = list_subs ? subs.reject {|sub| is_archiver?(sub)}.sort : subs.reject {|sub| is_archiver?(sub)}.size
        else
          subscribers["#{list}@#{dom}"] = list_subs ? subs.sort : subs.size
        end
      end
      return subscribers.to_h, File.mtime(LIST_TIME)
    end

    # for a mail domain, extract related lists and their subscribers (default only the count)
    # also returns the time when the data was last checked
    # N.B. excludes known archivers
    # For top-level apache.org lists, the mail_domain is either:
    # - the full list name (e.g. press), or:
    # - the list prefix (e.g. legal)
    # If podling==true, then also check for old-style podling names
    # If list_subs==true, return subscriber emails else sub count
    # Matches:
    # {mail_domain}.apache.org/*
    # apache.org/{mail_domain}(-.*)? (e.g. press, legal)
    # incubator.apache.org/{mail_domain}-.* (if podling==true)
    # Returns: {list}@{dom}
    def self.list_subs(mail_domain, podling=false, list_subs=false)
      self.list_subscribers(mail_domain, podling, list_subs, true)
    end

    # returns the list time
    def self.list_time
      File.mtime(LIST_TIME)
    end

    def self.list_archivers
      list_parse('sub') do |dom, list, subs|
        yield [dom, list, subs.select {|s| is_archiver? s}.map {|m| [m, archiver_type(m, dom, list)].flatten}]
      end
    end

    # return the [domain, list, types=public|private|...] for all entries in the subscriber listings
    # the subscribers are not included
    def self.list_types(show_all=false)
      list_archivers do |dom, list, subs|
        types = {}
        subs.each do |sub|
          type = sub[2]
          types[type] = 1 unless %w(alias direct).include? type
        end
        type = types.keys.sort.join(',')
        yield [dom, list, type] if show_all || type == 'public'
      end
    end

    # return a hash of lists for a project, together with privacy setting
    # tlp - the prefix for the full domain
    # This is a replacement for ASF::Mail.lists
    def self.domain_lists(project, show_all)
      lists = {}
      list_types(show_all) do |dom, list, type|
        if matches_list?(project, dom, list)
          lists["#{list}@#{dom}"] = type
        end
      end
      lists
    end
    # return the [domain, list] for all entries in the subscriber listings
    # the subscribers are not included
    def self.each_list
      Find.find(LIST_CACHE) do |path|
        parts = path.split('/')
        if parts[-1] == 'sub'
          yield [parts[-3], parts[-2]]
        end
      end
    end

    private

    # return the archiver type as array: [:MBOX|:PONY|:MINO|:MAIL_ARCH|:MARKMAIL|:WHIMSY, 'public'|'private'|'alias'|'direct']
    # minotaur archiver names do not include any public/private indication
    def self.archiver_type(email, dom, list)
      case email
        when ARCH_MBOX_PUB then return [:MBOX, 'public']
        when ARCH_MBOX_PRV then return [:MBOX, 'private']
        when ARCH_MBOX_RST then return [:MBOX, 'restricted']
        when ARCH_PONY_PUB then return [:PONY, 'public']
        when ARCH_PONY_PRV then return [:PONY, 'private']
        when ARCH_EXT_MAIL_ARCHIVE then return [:MAIL_ARCH, 'public']
        # normal archiver routed via .qmail-[tlp-]list-archive
        when "#{list}-archive@#{dom}" then return [:MINO, 'alias']
        # Direct mail to minotaur
        when "apmail-#{dom.split('.').first}-#{list}-archive@www.apache.org" then return [:MINO, 'direct']
        # Unexpected archiver email commits-archive@incubator.apache.org for commits.deprecated@incubator.apache.org
        # INFRA-21658
        when "#{list.chomp('.deprecated')}-archive@#{dom}" then return [:MINO, 'alias']
        else
          return [:MARKMAIL, 'public'] if is_markmail_archiver?(email)
          # Whimsy currently only 'archives' private lists
          return [:WHIMSY, 'private'] if is_whimsy_archiver?(email)
      end
      raise "Unexpected archiver email #{email} for #{list}@#{dom}" # Should not happen?
    end

    # Is the email a minotaur archiver?
    def self.is_mino_archiver?(e)
      e =~ /.-archive@([^.]+\.)?(apache\.org|apachecon\.com)$/
    end

    # Is the email a Whimsy archiver?
    def self.is_whimsy_archiver?(e)
      e =~ /@whimsy(-vm\d+)?\.apache\.org$/
    end

    # Is the email a markmail archiver?
    def self.is_markmail_archiver?(e)
      e =~ ARCH_EXT_MARKMAIL_RE
    end

    def self.is_archiver?(e)
      ARCHIVERS.include?(e) or is_mino_archiver?(e) or is_whimsy_archiver?(e) or is_markmail_archiver?(e)
    end

    def self.is_private_archiver?(e)
      [ARCH_MBOX_PRV, ARCH_PONY_PRV].include?(e) or
        e =~ /^security-archive@.*\.apache\.org$/ or
        e =~ /^apmail-\w+-security-archive@www.apache.org/ # direct subscription
    end

    def self.downcase(array)
      array.map(&:downcase)
    end

    def self.isRecent(file)
      return File.exist?(file) && (Time.now - File.mtime(file)) < 60 * 60 * 5
    end

    # Filter the appropriate list, matching on domain and list
    # Params:
    # - type: 'mod' or 'sub' or 'dig'
    # - matchdom: must match the domain (e.g. 'httpd.apache.org')
    # - matchlist: must match the list (e.g. 'dev')
    # - archivers: whether to include standard ASF archivers (default true)
    # The email addresses are returned as an array. May be empty.
    # If there is no match, then nil is returned
    def self.list_filter(type, matchdom, matchlist, archivers=true)
      list = File.join(LIST_CACHE, matchdom, matchlist, type)
      if File.exist? list
        if archivers
          return File.read(list).split("\n")
        else
          return File.read(list).split("\n").reject {|e| is_archiver?(e)}
        end
      end
      return nil
    end

    # Scans the cache files
    # Param: type = 'mod' or 'sub' or 'dig'
    # Yields:
    # - domain (e.g. [xxx.].apache.org)
    # - list (e.g. dev)
    # - emails as an array
    def self.list_parse(type, &block)
      case type
      when 'dig'
        type = 'digest'
      when 'sub', 'mod'
        # pass
      else
        raise ArgumentError.new('type: expecting dig, mod or sub')
      end
      ctime = @@file_times[type] || 0
      mtime = File.mtime(LIST_TIME).to_i
      if mtime <= ctime
        cached = @@file_parsed[type]
        if cached
          begin
            cached.each do |d, l, m|
              block.call d, l, m # these are already frozen
            end
            return
          rescue WeakRef::RefError
            @@file_times[type] = 0
          end
        end
      else
        @@file_parsed[type] = nil
      end

      cache = [] # see if this preserves mod cache
      Find.find(LIST_CACHE) do |path|
        parts = path.split('/')
        if parts[-1] == type
          dom = parts[-3].downcase.freeze
          list = parts[-2].downcase.freeze
          begin
            # During mail migration links are used - allow for broken ones
            mails = File.read(path).split("\n")
            cache << [dom, list, mails]
            yield [dom, list, mails]
          rescue StandardError => e
            Wunderbar.warn e
          end
        end
      end
      @@file_parsed[type] = WeakRef.new(cache)
      @@file_times[type] = mtime
      nil # don't return file contents
    end

    # Standard ASF archivers
    ARCH_MBOX_PUB = "archiver@mbox-vm.apache.org"
    ARCH_MBOX_PRV = "private@mbox-vm.apache.org"
    ARCH_MBOX_RST = "restricted@mbox-vm.apache.org"

    ARCH_PONY_PUB = "archive-asf-public@cust-asf.ponee.io"
    ARCH_PONY_PRV = "archive-asf-private@cust-asf.ponee.io"

    # Standard external archivers (necessarily public)
    ARCH_EXT_MAIL_ARCHIVE = "archive@mail-archive.com"
    ARCH_EXT_MARKMAIL_RE = %r{^\w+\.\w+\.\w+@.\.markmail\.org$} # one.two.three@a.markmail.org

    ARCHIVERS = [ARCH_PONY_PRV, ARCH_PONY_PUB,
                 ARCH_MBOX_PUB, ARCH_MBOX_PRV, ARCH_MBOX_RST, ARCH_EXT_MAIL_ARCHIVE]

    # Private archivers
    ARCHIVERS_PRV = [ARCH_PONY_PRV, ARCH_MBOX_PRV]
     # TODO alias archivers: either add list or use RE to filter them

    LIST_BASE = ASF::Config[:subscriptions] # allow overrides for testing etc

    # If this file exists, it is the time when the data was last extracted
    # The mods and subs files are only updated if they have changed
    LIST_TIME = File.join(LIST_BASE, 'list-start')

    LIST_CACHE = File.join(LIST_BASE, 'cache')

  end
end

if __FILE__ == $0
  $LOAD_PATH.unshift '/srv/whimsy/lib'
  require 'whimsy/asf'
  domain = ARGV.shift || 'whimsical'
  mlist = ASF::Committee.find(domain).mail_list
  p mlist
  p ASF::MLIST.domain_lists(mlist, false)
  p ASF::MLIST.domain_lists(mlist, true)
  p ASF::MLIST.list_subscribers(domain)
  p ASF::MLIST.list_subscribers(domain, false, false, true)
  p ASF::MLIST.list_subs(domain)
  p ASF::MLIST.list_subscribers(domain, false, true)
  p ASF::MLIST.list_subscribers(domain, false, true, true)
  p ASF::MLIST.list_subs(domain, false, true)
  p ASF::MLIST.list_moderators(domain, true)
  p ASF::MLIST.private_subscribers(domain)
  p ASF::MLIST.moderates(['chrisd@apache.org'])
  p ASF::MLIST.digests(['chrisd@apache.org'])
end
