# get entry for @userid
require 'wunderbar'
user = ASF::Person.find(@userid)
entry = user.members_txt(true)
raise Exception.new("Unable to find member entry for #{@userid}") unless entry
USERID = user.id
USERMAIL = "#{USERID}@apache.org"
USERNAME = user.cn
TIMESTAMP = (DateTime.now.strftime "%Y-%m-%d %H:%M:%S %:z")

# identify file to be updated
members_txt = ASF::SVN.svnpath!('foundation', 'members.txt')
# construct commit message
message = "Action #{@action} for #{USERID}"

# update members.txt only for secretary actions
if @action == 'emeritus' or @action == 'active' or @action == 'deceased'
  ASF::SVN.multiUpdate_ members_txt, message, env, _ do |text|
    # remove user's entry
    unless text.sub! entry, '' # e.g. if the workspace was out of date
      raise Exception.new("Failed to remove existing entry -- try refreshing")
    end

    extra = []

    # determine where to put the entry
    if @action == 'emeritus'
      index = text.index(/^\s\*\)\s/, text.index(/^Emeritus/))
      entry.sub! %r{\s*/\* deceased, .+?\*/},'' # drop the deceased comment if necessary
      # if pending emeritus request was found, move it to emeritus
      pathname, basename = ASF::EmeritusRequestFiles.findpath(user)
      if pathname
        extra << ['mv', pathname, ASF::SVN.svnpath!('emeritus', basename)]
      else # there should be a request file
        _warn "Emeritus request file not found"
      end
    elsif @action == 'active'
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
end

# Owner operations
if @action == 'rescind_emeritus'
  # TODO handle case where rescinded file already exists
  pathname, basename = ASF::EmeritusRequestFiles.findpath(user)
  if pathname
    ASF::SVN.svn_!('mv', [pathname, ASF::SVN.svnpath!('emeritus-requests-rescinded', basename)], _, {env:env, msg:message})
  else
    _warn "Emeritus request file not found"
  end
elsif @action == 'request_emeritus'
  # Create emeritus request and send acknowledgement mail from secretary
  # TODO URL should be a config constant ...
  code, template = ASF::Git.github('apache/www-site/main/content/forms/emeritus-request.txt')
  raise "Failed to read emeritus-request.txt: " + code unless code == "200"
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
      from "secretary@apache.org"
      to "#{USERNAME}<#{USERMAIL}>"
      subject "Acknowledgement of emeritus request from #{USERNAME}"
      text_part do
        body "This acknowledges receipt of your emeritus request. You can find the request at #{EMERITUS_REQUEST_URL}#{USERID}.txt. A copy is attached for your records.\n\nWarm Regards,\n\nSecretary, Apache Software Foundation\nsecretary@apache.org\n\n"
      end
    end
    mail.attachments["#{USERID}.txt"] = signed_request
    mail.deliver!
  elsif rc == 1
    _warn "Request file already exists"
  end
elsif @action == 'request_reinstatement'
  ASF::Mail.configure
  mail = Mail.new do
    to "secretary@apache.org"
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
