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

  module MLIST
    # utility methods for handling mailing list subscriptions and moderations

    # whilst the source files are not particularly difficult to parse, it makes
    # sense to centralise access so any necessary changes can be localised

    # Note that email matching is case blind, but the original case is returned
    # list and domain names are always returned as lower-case

    # Potentially also the methods could check if access was allowed.
    # This is currently done by the callers

    # Note that the data files don't provide information on whether a list is
    # public or private.

    @@file_times  = Hash.new # Key=type, value = modtime
    @@file_parsed = Hash.new # Key=type, value = cache hash

    # Return an array of board subscribers followed by the file update time
    def self.board_subscribers(archivers=true)
      return list_filter('sub', 'apache.org', 'board', archivers), (File.mtime(LIST_TIME) rescue File.mtime(LIST_SUBS))
    end

    # Return an array of members@ subscribers followed by the file update time
    def self.members_subscribers(archivers=true)
      return list_filter('sub', 'apache.org', 'members', archivers), (File.mtime(LIST_TIME) rescue File.mtime(LIST_SUBS))
    end

    # Return an array of private@pmc subscribers followed by the file update time
    # By default does not return the standard archivers
    # pmc can either be a pmc name, in which case it uses private@<pmc>.apache.org
    # or it can be an ASF list name, e.g. w3c@apache.org
    def self.private_subscribers(pmc, archivers=false)
      parts = pmc.split('@', 3) # want to detect trailing '@'
      if parts.length == 1
        return list_filter('sub', "#{pmc}.apache.org", 'private', archivers), (File.mtime(LIST_TIME) rescue File.mtime(LIST_SUBS))
      elsif parts.length == 2 && parts[1] == 'apache.org'
        return list_filter('sub', parts[1], parts[0], archivers), (File.mtime(LIST_TIME) rescue File.mtime(LIST_SUBS))
      else
        raise "Unexpected parameter: #{pmc}"
      end
    end

    def self.security_subscribers(pmc, archivers=false)
      return list_filter('sub', "#{pmc}.apache.org", 'security', archivers), (File.mtime(LIST_TIME) rescue File.mtime(LIST_SUBS))
    end

    # return a hash of subscriptions for the list of emails provided
    # the following keys are added to the response hash:
    # :subtime - the timestamp when the data was last updated
    # :subscriptions - an array of pairs: [list name, subscriber email]
    # N.B. not the same format as the moderates() method
    def self.subscriptions(emails, response = {})
      
      return response unless File.exists? LIST_SUBS

      response[:subscriptions] = []
      response[:subtime] = (File.mtime(LIST_TIME) rescue File.mtime(LIST_SUBS))

      _emails = emails.map{|email| ASF::Mail.to_canonical(email.downcase)}
      list_parse('sub') do |dom, list, subs|
        subs.each do |sub|
          if _emails.include? ASF::Mail.to_canonical(sub.downcase)
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
      
      return response unless File.exists? LIST_DIGS

      response[:digests] = []
      response[:digtime] = (File.mtime(LIST_TIME) rescue File.mtime(LIST_DIGS))

      _emails = emails.map{|email| ASF::Mail.to_canonical(email.downcase)}
      list_parse('dig') do |dom, list, subs|
        subs.each do |sub|
          if _emails.include? ASF::Mail.to_canonical(sub.downcase)
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

      return response unless File.exists? LIST_MODS

      response[:moderates] = {}
      response[:modtime] = (File.mtime(LIST_TIME) rescue File.mtime(LIST_MODS))
      umails = user_emails.map{|m| ASF::Mail.to_canonical(m.downcase)} # outside loop
      list_parse('mod') do |dom, list, emails|
        matching = emails.select{|m| umails.include? ASF::Mail.to_canonical(m.downcase)}
        response[:moderates]["#{list}@#{dom}"] = matching unless matching.empty?
      end
      response
    end

    # for a mail domain, extract related lists and their moderators
    # also returns the time when the data was last checked
    # If podling==true, then also check for old-style podling names
    def self.list_moderators(mail_domain, podling=false)

      return nil, nil unless File.exist? LIST_MODS

      moderators = {}
      list_parse('mod') do |dom, list, subs|

        # drop infra test lists
        next if list =~ /^infra-[a-z]$/
        next if dom == 'incubator.apache.org' && list =~ /^infra-dev2?$/

        # normal tlp style:
        #/home/apmail/lists/commons.apache.org/dev/mod
        # possible podling styles (new, old):
        #/home/apmail/lists/batchee.apache.org/dev/mod
        #/home/apmail/lists/incubator.apache.org/blur-dev/mod
        #Apache lists (e.g. some non-PMCs)
        #/home/apmail/lists/apache.org/list/mod
        next unless "#{mail_domain}.apache.org" == dom or
           (dom == 'apache.org' &&  list =~ /^#{mail_domain}(-|$)/) or
           (podling && dom == 'incubator.apache.org' && list =~ /^#{mail_domain}-/)
        moderators["#{list}@#{dom}"] = subs.sort
      end
      return moderators.to_h, (File.mtime(LIST_TIME) rescue File.mtime(LIST_MODS))
    end

    # for a mail domain, extract related lists and their subscribers (default only the count)
    # also returns the time when the data was last checked
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
    def self.list_subscribers(mail_domain, podling=false, list_subs=false)

      return nil, nil unless File.exist? LIST_SUBS

      subscribers = {}
      list_parse('sub') do |dom, list, subs|

        # drop infra test lists
        next if list =~ /^infra-[a-z]$/
        next if dom == 'incubator.apache.org' && list =~ /^infra-dev2?$/

        # normal tlp style:
        #/home/apmail/lists/commons.apache.org/dev/mod

        # possible podling styles (new, old):
        #/home/apmail/lists/batchee.apache.org/dev/mod
        #/home/apmail/lists/incubator.apache.org/blur-dev/mod

        #Apache lists (e.g. some non-PMCs)
        #/home/apmail/lists/apache.org/list/mod

        next unless "#{mail_domain}.apache.org" == dom or
           (dom == 'apache.org' &&  list =~ /^#{mail_domain}(-|$)/) or
           (podling && dom == 'incubator.apache.org' && list =~ /^#{mail_domain}-/)
        subscribers["#{list}@#{dom}"] = list_subs ? subs.sort : subs.size
      end
      return subscribers.to_h, (File.mtime(LIST_TIME) rescue File.mtime(LIST_SUBS))
    end

    # returns the list time (defaulting to list-subs time if the marker is not present)
    def self.list_time
      File.mtime(LIST_TIME) rescue File.mtime(LIST_SUBS)
    end

    def self.list_archivers
      list_parse('sub') do |dom, list, subs|
        yield [dom, list, subs.select {|s| is_archiver? s}.map{|m| [m,archiver_type(m,dom,list)].flatten}]
      end
    end

    # return the [domain, list] for all entries in the subscriber listings
    # the subscribers are not included 
    def self.each_list
      list_parse('sub') do |dom, list, subs|
        yield [dom, list]
      end
    end

    private

    # return the archiver type as array: [:MBOX|:PONY|:MINO|:MAIL_ARCH|:MARKMAIL, 'public'|'private'|'alias'|'direct']
    # minotaur archiver names do not include any public/private indication as that is in bin/.archives
    def self.archiver_type(email, dom,list)
      case email
        when ARCH_MBOX_PUB then return [:MBOX, 'public']
        when ARCH_MBOX_PRV then return [:MBOX, 'private']
        when ARCH_PONY_PUB then return [:PONY, 'public']
        when ARCH_PONY_PRV then return [:PONY, 'private']
        when ARCH_EXT_MAIL_ARCHIVE then return [:MAIL_ARCH, 'public']
        # normal archiver routed via .qmail-[tlp-]list-archive
        when "#{list}-archive@#{dom}" then return [:MINO, 'alias']
        # Direct mail to minotaur
        when "apmail-#{dom.split('.').first}-#{list}-archive@www.apache.org" then return [:MINO, 'direct']
      else
        return [:MARKMAIL, 'public'] if is_markmail_archiver?(email)
      end
      raise "Unexpected archiver email #{email} for #{list}@#{dom}" # Should not happen?
    end

    # Is the email a minotaur archiver?
    def self.is_mino_archiver? (e)
      e =~ /.-archive@([^.]+\.)?(apache\.org|apachecon\.com)$/
    end

    # Is the email a Whimsy archiver?
    def self.is_whimsy_archiver? (e)
      e =~ /@whimsy(-vm\d+)?\.apache\.org$/
    end

    # Is the email a markmail archiver?
    def self.is_markmail_archiver? (e)
      e =~ ARCH_EXT_MARKMAIL_RE
    end

    def self.is_archiver? (e)
      ARCHIVERS.include?(e) or is_mino_archiver?(e) or is_whimsy_archiver?(e) or is_markmail_archiver?(e)
    end

    def self.downcase(array)
      array.map{|m| m.downcase}
    end

    def self.isRecent(file)
      return File.exist?(file) && ( Time.now - File.mtime(file) ) < 60*60*5
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
      list_parse(type) do |dom, list, emails|
          if matchdom == dom && matchlist == list
            if archivers
              return emails
            else
            return emails.reject{|e| is_archiver?(e)}
            end
          end
      end
      return nil
    end
    
    # Parses the list-mods/list-subs files
    # Param: type = 'mod' or 'sub' or 'dig'
    # Yields:
    # - domain (e.g. [xxx.].apache.org)
    # - list (e.g. dev)
    # - emails as an array
    def self.list_parse(type)
      if type == 'mod'
        path = LIST_MODS
        suffix = '/mod'
      elsif type == 'sub'
        path = LIST_SUBS
        suffix = ''
      elsif type == 'dig'
        path = LIST_DIGS
        suffix = ''
      else
        raise ArgumentError.new('type: expecting dig, mod or sub')
      end
      ctime = @@file_times[type] || 0
      mtime = File.mtime(path).to_i
      if mtime <= ctime
        cached = @@file_parsed[type]
        if cached
          begin
            cached.each do |d,l,m|
              yield d, l, m
            end
            return
          rescue WeakRef::RefError
            @@file_times[type] = 0
          end
        end
      else
        @@file_parsed[type] = nil
      end
      cache = Array.new # see if this preserves mod cache
      # split file into paragraphs
      File.read(path).split(/\n\n/).each do |stanza|
        # domain may start in column 1 or following a '/'
        # match [/home/apmail/lists/][accumulo.]apache.org/dev[/mod]
        # list names can include '-': empire-db
        # or    [/home/apmail/lists/]apachecon.com/announce[/mod]
        match = stanza.match(%r{(?:^|/)([-\w]*\.?apache\.org|apachecon\.com)/(.*?)#{suffix}(?:\n|\Z)})
        if match
          dom = match[1].downcase # just in case
          list = match[2].downcase # just in case
          # Keep original case of email addresses
          # TODO: a bit slow for subs file, implement cache of parsed file?
          mails = stanza.split(/\n/).select{|x| x =~ /@/}
          cache << [dom, list, mails]
          yield dom, list, mails
        else
          # don't allow mismatches as that means the RE is wrong
          line=stanza[0..(stanza.index("\n")|| -1)]
          raise ArgumentError.new("Unexpected section header #{line}")
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
    # TODO alias archivers: either add list or use RE to filter them

    LIST_MODS = '/srv/subscriptions/list-mods'

    LIST_SUBS = '/srv/subscriptions/list-subs'

    LIST_DIGS = '/srv/subscriptions/list-digs'

    # If this file exists, it is the time when the data was last extracted
    # The mods and subs files are only updated if they have changed
    LIST_TIME = '/srv/subscriptions/list-start'

  end
end

#if __FILE__ == $0
#  domain = ARGV.shift||'whimsical'
#  p  ASF::MLIST.list_subscribers(domain)
#  p  ASF::MLIST.list_subscribers(domain,false,true)
#  exit
#  p  ASF::MLIST.list_moderators(domain, true)
#  p  ASF::MLIST.private_subscribers(domain)
#  p  ASF::MLIST.digests(['chrisd@apache.org'])
#end
