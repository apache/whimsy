# get entry for @userid
require 'wunderbar'
user = ASF::Person.find(@userid)
entry = user.members_txt(true)
raise Exception.new("Unable to find member entry for #{@userid}") unless entry
USERID = user.id.untaint
USERMAIL = "#{USERID}@apache.org".untaint
USERNAME = user.cn.untaint
TIMESTAMP = (DateTime.now.strftime "%Y-%m-%d %H:%M:%S").untaint

# identify file to be updated
members_txt = ASF::SVN.svnpath!('foundation', 'members.txt').untaint
# construct commit message
message = "Action #{@action} for #{USERID}"

# only update members if needed
updmem = @action == 'emeritus' or @action == 'active' or @action == 'deceased'

# update members.txt only for secretary actions
if updmem
  ASF::SVN.multiUpdate_ members_txt, message, env, _ do |text|
    # remove user's entry
    unless text.sub! entry, '' # e.g. if the workspace was out of date
      raise Exception.new("Failed to remove existing entry -- try refreshing")
    end

    # determine where to put the entry
    if @action == 'emeritus'
      index = text.index(/^\s\*\)\s/, text.index(/^Emeritus/))
      entry.sub! %r{\s*/\* deceased, .+?\*/},'' # drop the deceased comment if necessary
      # if pending emeritus request was found, move it to emeritus
      extra = []
      # If emeritus request was found, move it to emeritus
      filename = ASF::EmeritusRequestFiles.extractfilename(@emeritusfileurl)
      if filename
        emeritus_destination_url = ASF::SVN.svnpath!('emeritus', filename)
        extra << ['mv', @emeritusfileurl, emeritus_destination_url]
      end
    elsif @action == 'active'
      index = text.index(/^\s\*\)\s/, text.index(/^Active/))
      entry.sub! %r{\s*/\* deceased, .+?\*/},'' # drop the deceased comment if necessary
      # if emeritus file was found, move it to emeritus-reinstated
      filename = ASF::EmeritusFiles.extractfilename(@emeritusfileurl)
      if filename
        emeritus_destination_url = ASF::SVN.svnpath!('emeritus-reinstated', filename)
        extra << ['mv', @emeritusfileurl, emeritus_destination_url]
      end
    elsif @action == 'deceased'
      index = text.index(/^\s\*\)\s/, text.index(/^Deceased/))
      entry.sub! %r{\n}, " /* deceased, #{@dod} */\n" # add the deceased comment
    end

    # perform the insertion
    text.insert index, entry

    # return the updated (and normalized) text and extra svn command
    [text, extra]
  end
end

# Owner operations
if @action == 'rescind_emeritus'
  emeritus_rescinded_url = ASF::SVN.svnurl('emeritus-requests-rescinded')
  ASF::SVN.svn_('mv', [@emeritusfileurl, emeritus_rescinded_url], _, {env:env, msg:message})
elsif @action == 'request_emeritus'
  # Create emeritus request and send mail from secretary
  FOUNDATION_URL = ASF::SVN.svnurl('foundation')
  EMERITUS_TEMPLATE_URL = ASF::SVN.svnpath!('foundation', 'emeritus-request.txt').untaint
  template, err =
    ASF::SVN.svn('cat', EMERITUS_TEMPLATE_URL, {env:env})
  raise RuntimeError.new("Failed to read emeritus-request.txt: " + err) unless template
  centered_id = "#{USERID}".center(55, '_')
  centered_name = "#{USERNAME}".center(55, '_')
  centered_date ="#{TIMESTAMP}".center(55, '_')
  signed_request = template
    .gsub('Apache id: _______________________________________________________',
        ('Apache id: ' + centered_id))
    .gsub('Full name: _______________________________________________________',
          ('Full name: ' + centered_name))
    .gsub('Signed: __________________________________________________________',
          'Signed by validated user at: ________Whimsy www/committer_________')
    .gsub('Date: _________________________________',
          ('Date: _______' + centered_date))
  # Write the emeritus request to emeritus-requests-received
  EMERITUS_REQUEST_URL = ASF::SVN.svnpath('emeritus-requests-received').untaint
  rc = ASF::SVN.create_(EMERITUS_REQUEST_URL, "#{USERID}.txt", signed_request, "Emeritus request from #{USERNAME}  (#{USERID}", env, _)
  if rc == 1 break # do nothing if there is already an emeritus request

  ASF::Mail.configure
  mail = Mail.new do
    from "secretary@apache.org"
    to "#{USERNAME}<#{USERMAIL}>"
    subject "Emeritus request acknowledgement from #{USERNAME}"
    text_part do
      body "This acknowledges receipt of your emeritus request. You can find the request at #{EMERITUS_REQUEST_URL}/#{USERID}.txt. A copy is attached for your records.\n\nRegards,\n\nsecretary@apache.org\n\n"
    end
  end
  mail.attachments["#{USERID}.txt"] = signed_request.untaint
  mail.deliver!
elsif @action == 'request_reinstatement'
  ASF::Mail.configure
  mail = Mail.new do
    to "secretary@apache.org"
    cc "#{USERNAME}<#{USERMAIL}>"
    from "#{USERMAIL}"
    subject "Emeritus reinstatement request from #{USERNAME}"
    text_part do
      body "I respectfully request reinstatement to full membership in The Apache Software Foundation.\n\nRegards,\n\n#{USERNAME}"
    end
  end
  mail.deliver!
end

# return updated committer info
_committer Committer.serialize(@userid, env)
