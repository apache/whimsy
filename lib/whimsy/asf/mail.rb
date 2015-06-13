
module ASF

  class Mail
    def self.list
      return @list if @list

      list = Hash.new

      # load info from LDAP
      ASF::Person.preload(['mail', 'asf-altEmail'])
      ASF::Person.collection.each do |name, person|
        (person.mail+person.alt_email).each do |mail|
          list[mail.downcase] = person
        end
      end

      # load all member emails in one pass
      ASF::Member.each do |id, text|
        Member.emails(text).each {|mail| list[mail.downcase] ||= Person[id]}
      end

      # load all ICLA emails in one pass
      ASF::ICLA.new.each do |id, name, email|
        list[email.downcase] ||= Person.find(id)
        next if id == 'notinavail'
        list["#{id.downcase}@apache.org"] ||= Person.find(id)
      end

      @list = list
    end

    def self.lists(public_private= false)
      apmail_bin = ASF::SVN['infra/infrastructure/apmail/trunk/bin']
      file = File.join(apmail_bin, '.archives')
      if not @lists or File.mtime(file) != @list_mtime
        @list_mtime = File.mtime(file)
        @lists = Hash[File.read(file).scan(
          /^\s+"(\w[-\w]+)", "\/home\/apmail\/(public|private)-arch\//
        )]
      end

      public_private ? @lists : @lists.keys
    end
  end

  class Person < Base
    def self.find_by_email(value)
      value.downcase!

      person = Mail.list[value]
      return person if person
    end

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

    def active_emails
      (mail + alt_email + member_emails).uniq
    end

    def all_mail
      active_emails + obsolete_emails
    end
  end

  class Committee
    def mail_list
      case name.downcase
      when 'httpcomponents'
        'hc'
      when 'tac'
        'travel-assistance'
      when 'whimsy'
        'whimsical'
      else
        name
      end
    end
  end
end
