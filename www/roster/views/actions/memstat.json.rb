# get entry for @userid
require 'wunderbar'
user = ASF::Person.find(@userid)
entry = user.members_txt(true)
raise Exception.new("Unable to find member entry for #{@userid}") unless entry
USERID = user.id.dup.untaint # might be frozen
USERMAIL = "#{USERID}@apache.org".untaint
USERNAME = user.cn.untaint
TIMESTAMP = (DateTime.now.strftime "%Y-%m-%d %H:%M:%S").untaint

# identify file to be updated
members_txt = ASF::SVN.svnpath!('foundation', 'members.txt').untaint
# construct commit message
message = "Action #{@action} for #{USERID}"

# update members.txt only for secretary actions
if @action == 'emeritus' or @action == 'active' or @action == 'deceased'
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
  # Create mail to secretary requesting emeritus
  template, err =
    ASF::SVN.svn('cat', ASF::SVN.svnpath!('foundation', 'emeritus-request.txt').untaint, {env:env})
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

  ASF::Mail.configure
  mail = Mail.new do
    to "secretary@apache.org"
    cc "#{USERNAME}<#{USERMAIL}>"
    from "#{USERMAIL}"
    subject "Emeritus request from #{USERNAME}"
    text_part do
      body "Please accept my emeritus request, which is attached.\n\nRegards,\n\n#{USERNAME}\n\n"
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
      body "I respectfully request reinstatement to full membership.\n\nRegards,\n\n#{USERNAME}"
    end
  end
  mail.deliver!
end

# return updated committer info
_committer Committer.serialize(@userid, env)
