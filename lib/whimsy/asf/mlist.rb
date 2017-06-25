module ASF

  module MLIST
    # utility methods for handling mailing list subscriptions and moderations

    # whilst the source files are not particularly difficult to parse, it makes
    # sense to centralise access so any necessary changes can be localised

    # Potentially also the methods could check if access was allowed.
    # This is currently done by the callers
    
    def self.board_subscribers
      # yield the list of board subscribers
      File.readlines(BOARD_SUBSCRIPTIONS).each do |line|
        yield line.strip
      end
    end

    def self.members_subscribers
      # yield the list of subscribers to members@
      File.readlines(MEMBERS_SUBSCRIPTIONS).each do |line|
        yield line.strip
      end
    end

    def self.incubator_mods
      # return a hash of incubator moderators
      # list-name => [subscribers]
      moderators = Hash[File.read(LIST_MODS).split(/\n\n/).
        select {|k,v| k =~ /incubator.apache.org/ && k !~ /\/infra-(dev2?|[a-z])\//}.
        map {|stanza| [stanza[/incubator.apache.org\/(.*)\//,1],
        stanza.scan(/^(.*@.*)/).flatten]}]
      moderators
    end

    def self.subscriptions(emails, response = {})
      # return a hash of subscriptions for the list of emails provided
      
      return response unless File.exists? LIST_SUBS

      response[:subscriptions] = []
      response[:subtime] = File.mtime(LIST_SUBS)

      # File format
      # blank line
      # /home/apmail/lists/accumulo.apache.org/commits
      # archive@mail-archive.com
      # ...
      File.read(LIST_SUBS).split(/\n\n/).each do |stanza|
        # list names can include '-': empire-db
        list = stanza.match(/\/([-\w]*\.?apache\.org)\/(.*?)(\n|\Z)/)

        subs = stanza.scan(/^(.*@.*)/).flatten
        emails.each do |email|
          if subs.include? email
            response[:subscriptions] << ["#{list[2]}@#{list[1]}", email]
          end
        end
      end
      response
    end

    def self.moderates(user_emails, response = {})
      # return the mailing lists which are moderated by any of the list of emails

      return response unless File.exists? LIST_MODS

      response[:moderates] = {}
      response[:modtime] = File.mtime(LIST_MODS)
      moderators = File.read(LIST_MODS).split(/\n\n/).map do |stanza|
        # list names can include '-': empire-db
        list = stanza.match(/\/([-\w]*\.?apache\.org)\/(.*?)\//)

        ["#{list[2]}@#{list[1]}", stanza.scan(/^(.*@.*)/).flatten]
      end

      moderators.each do |mail_list, list_moderators|
        matches = (list_moderators & user_emails)
        response[:moderates][mail_list] = matches unless matches.empty?
      end
      response
    end

    def self.list_moderators(mail_domain, podling=false)
      # for a mail domain, extract related lists and their moderators
      # also returns the time when the data was last checked
      # If podling==true, then also check for old-style podling names

      return nil, nil unless File.exist? LIST_MODS

      moderators = File.read(LIST_MODS).split(/\n\n/).map do |stanza|
        # list names can include '-': empire-db
        m = stanza.match(/\/(?'domain'[-\w]+)\.apache\.org\/(?'sublist'.*?)\//)
        # normal tlp style:
        #/home/apmail/lists/commons.apache.org/dev/mod
        # possible podling styles (new, old):
        #/home/apmail/lists/batchee.apache.org/dev/mod
        #/home/apmail/lists/incubator.apache.org/blur-dev/mod
        next unless m # did not parse
        # drop infra test lists
        next if m['sublist'] =~ /^infra-[a-z]$/
        next if m['domain'] == 'incubator' && m['sublist'] =~ /^infra-dev2?$/
        # if podling, also check for old-style names
        # we need to check for incubator domain to avoid spurious matches, e.g. with
        # /home/apmail/lists/db.apache.org/commons-dev/mod

        next unless m['domain'] == mail_domain or
            (podling && m['domain'] == 'incubator' && m['sublist'] =~ /^#{mail_domain}-/)
 
        ["#{m['sublist']}@#{m['domain']}.apache.org", stanza.scan(/^(.*@.*)/).flatten.sort]
      end
      return moderators.compact.to_h, File.mtime(LIST_MODS)
    end

    private

    # board and member subs details are part of LIST_SUBS
    # however they are generated more frequently at present
    # the files could be dropped if/when that changes
    MEMBERS_SUBSCRIPTIONS = '/srv/subscriptions/members'

    BOARD_SUBSCRIPTIONS = '/srv/subscriptions/board'
    
    LIST_MODS = '/srv/subscriptions/list-mods'

    LIST_SUBS = '/srv/subscriptions/list-subs'

  end
end
#if __FILE__ == $0
#p  ASF::MLIST.list_moderators(ARGV.shift||'blur', true)
#end
