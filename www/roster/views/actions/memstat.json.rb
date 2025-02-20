# get entry for @userid
require 'wunderbar'

user = ASF::Person.find(@userid)
entry = user.members_txt(true)
raise Exception.new("Unable to find member entry for #{@userid}") unless entry
USERID = user.id
USERMAIL = "#{USERID}@apache.org"
USERNAME = user.cn
TIMESTAMP = (Time.now.strftime '%Y-%m-%d %H:%M:%S %:z')

# identify file to be updated
members_txt = ASF::SVN.svnpath!('foundation', 'members.txt')
# construct commit message
message = "Action #{@action} for #{USERID}"

# update members.txt only for secretary actions
if @action == 'emeritus' or @action == 'active' or @action == 'deceased'
  ASF::SVN.multiUpdate_ members_txt, message, env, _ do |text|
    # remove user's entry
    unless text.sub! entry, '' # e.g. if the workspace was out of date
      raise Exception.new('Failed to remove existing entry -- try refreshing')
    end

    extra = []

    # determine where to put the entry
    if @action == 'emeritus' # move to emeritus
      index = text.index(/^\s\*\)\s/, text.index(/^Emeritus/))
      entry.sub! %r{\s*/\* deceased, .+?\*/},'' # drop the deceased comment if necessary
      # if pending emeritus request was found, move it to emeritus
      pathname, basename = ASF::EmeritusRequestFiles.findpath(user)
      if pathname
        extra << ['mv', pathname, ASF::SVN.svnpath!('emeritus', basename)]
      else # there should be a request file
        _warn 'Emeritus request file not found'
      end
    elsif @action == 'active' # revert to active
      index = text.index(/^\s\*\)\s/, text.index(/^Active/))
      entry.sub! %r{\s*/\* deceased, .+?\*/},'' # drop the deceased comment if necessary
      # if emeritus file was found, move it to emeritus-reinstated
      # otherwise ignore
      pathname, basename = ASF::EmeritusFiles.findpath(user)
      if pathname
        # TODO: allow for previous reinstated file
        extra << ['mv', pathname,  ASF::SVN.svnpath!('emeritus-reinstated', basename)]
      end
    elsif @action == 'deceased'
      index = text.index(/^\s\*\)\s/, text.index(/^Deceased/))
      entry.sub! "\n", " /* deceased, #{@dod} */\n" # add the deceased comment
    end

    # perform the insertion
    text.insert index, entry

    # return the updated (and normalized) text and extra svn command
    [ASF::Member.normalize(text), extra]
  end

elsif @action == 'withdraw' # process withdrawal request (secretary only)
  require 'whimsy/asf/subreq'

  # TODO
  # Check members.md for entry and report - how?

  # unsubscribe from member only mailing lists:
  all_mail = user.all_mail # their known emails
  pmc_chair = ASF.pmc_chairs.include?(user)
  # to which (P)PMCs do they belong?
  ldap_pmcs = user.committees.map(&:mail_list)
  ldap_pmcs += user.podlings.map(&:mail_list)
  # What are their subscriptions?
  subs = ASF::MLIST.subscriptions(all_mail)[:subscriptions]
  subs += ASF::MLIST.digests(all_mail)[:digests]
  # Check subscriptions for readability
  subs.each do |list, email|
    unless ASF::Mail.canread(list, false, pmc_chair, ldap_pmcs)
      request = ASF::Subreq.create_request(user, email, list)
      ASF::Subreq.queue_request('unsub', request, nil, {env: env})
    end
  end
  # remove from LDAP member group
  ASF::LDAP.bind(env.user, env.password) do
    ASF::Group['member'].remove(user)
  end

  # Remove from members.txt
  Tempfile.create('withdraw') do |tempfile|
    ASF::SVN.multiUpdate_ members_txt, message, env, _, {verbose: true} do |text|
      extra = []
      # remove user's entry
      unless text.sub! entry, '' # e.g. if the workspace was out of date
        raise Exception.new('Failed to remove existing entry -- try refreshing')
      end
      # save the entry to the archive
      File.write(tempfile, entry)
      tempfile.close
      extra << ['put' , tempfile.path, ASF::SVN.svnpath!('withdrawn', 'archive', "#{@userid}.txt")]

      # Find matching request for the id
      pathname, basename = ASF::WithdrawalRequestFiles.findpath(@userid, env)
      unless pathname
        raise Exception.new("Failed to find withdrawal pending file for #{@userid}")
      end

      # Move the request from pending - this should also work for directories
      extra << ['mv', pathname, ASF::SVN.svnpath!('withdrawn', basename)]
      [ASF::Member.normalize(text), extra]
    end
    ASF::WithdrawalRequestFiles.refreshnames(true, env) # update the listing if successful

    # Send confirmation email
    ASF::Mail.configure
    mail = Mail.new do
      from 'secretary@apache.org'
      to "#{USERNAME}<#{USERMAIL}>"
      subject "Acknowledgement of membership withdrawal from #{USERNAME}"
      text_part do
        body <<~EOD
        The membership withdrawal request that was registered for you has now been actioned.
        Your details have been removed from the membership roster.
        You have also been unsubscribed from members-only private email lists.
        
        Warm Regards,
        
        Secretary, Apache Software Foundation
        secretary@apache.org
        EOD
      end
    end
    mail.deliver!
  end

elsif @action == 'rescind_withdrawal' # Secretary only
  pathname, _basename = ASF::WithdrawalRequestFiles.findpath(@userid, env)
  if pathname
    ASF::SVN.svn_!('rm', pathname, _, {env:env, msg:message})
    ASF::WithdrawalRequestFiles.refreshnames(true, env) # update the listing
    ASF::Mail.configure
    mail = Mail.new do
      from 'secretary@apache.org'
      to "#{USERNAME}<#{USERMAIL}>"
      subject "Acknowledgement of withdrawal rescindment from #{USERNAME}"
      text_part do
        body <<~EOD
        This acknowledges receipt of your request to rescind your membership withdrawal request.
        The request has been deleted, and your membership status will be unaffected.
        
        Warm Regards,
        
        Secretary, Apache Software Foundation
        secretary@apache.org
        EOD
      end
    end
    mail.deliver!
  else
    _warn "Withdrawal request file not found for #{@userid}"
  end
end

# Owner operations
if @action == 'rescind_emeritus'
  # TODO handle case where rescinded file already exists
  pathname, basename = ASF::EmeritusRequestFiles.findpath(user)
  if pathname
    ASF::SVN.svn_!('mv', [pathname, ASF::SVN.svnpath!('emeritus-requests-rescinded', basename)], _, {env:env, msg:message})
  else
    _warn 'Emeritus request file not found'
  end
elsif @action == 'request_emeritus'
  # Create emeritus request and send acknowledgement mail from secretary
  # TODO URL should be a config constant ...
  code, template = ASF::Git.github('apache/www-site/main/content/forms/emeritus-request.txt')
  raise 'Failed to read emeritus-request.txt: ' + code unless code == '200'
  centered_id = USERID.center(55, '_')
  centered_name = USERNAME.center(55, '_')
  centered_date = TIMESTAMP.center(25, '_')
  signed_request = template
    .sub(/Apache id: _+/, ('Apache id: ' + centered_id))
    .sub(/Full name: _+/, ('Full name: ' + centered_name))
    .sub(/Signed: _+/, 'Signed by validated user at: ________Whimsy www/committer_________')
    .sub(/Date: _+/, ('Date: ' + centered_date))
  # Write the emeritus request to emeritus-requests-received
  EMERITUS_REQUEST_URL = ASF::SVN.svnpath!('emeritus-requests-received')
  rc = ASF::SVN.create_(EMERITUS_REQUEST_URL, "#{USERID}.txt", signed_request, "Emeritus request from #{USERNAME} (#{USERID})", env, _)
  if rc == 0
    ASF::Mail.configure
    mail = Mail.new do
      from 'secretary@apache.org'
      to "#{USERNAME}<#{USERMAIL}>"
      subject "Acknowledgement of emeritus request from #{USERNAME}"
      text_part do
        body "This acknowledges receipt of your emeritus request. You can find the request at #{EMERITUS_REQUEST_URL}#{USERID}.txt. A copy is attached for your records.\n\nWarm Regards,\n\nSecretary, Apache Software Foundation\nsecretary@apache.org\n\n"
      end
    end
    mail.attachments["#{USERID}.txt"] = signed_request
    mail.deliver!
  elsif rc == 1
    _warn 'Request file already exists'
  end
elsif @action == 'request_reinstatement'
  ASF::Mail.configure
  mail = Mail.new do
    to 'secretary@apache.org'
    cc "#{USERNAME}<#{USERMAIL}>"
    from USERMAIL
    subject "Emeritus reinstatement request from #{USERNAME}"
    text_part do
      body "I respectfully request reinstatement to full membership in The Apache Software Foundation.\n\nRegards,\n\n#{USERNAME}"
    end
  end
  mail.deliver!
end

# return updated committer info
_committer Committer.serialize(@userid, env)
