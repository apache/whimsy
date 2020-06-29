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
members_txt = File.join(ASF::SVN['foundation'], 'members.txt').untaint

# construct commit message
message = "Action #{@action} for #{USERID}"

# only update members if needed
updmem = @action == 'emeritus' or @action == 'active' or @action == 'deceased'

# update members.txt only for secretary actions
if updmem
  ASF::SVN.multiUpdate_ members_txt, message, env, _ do |text|
    # default command is empty
    command = ""
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
      if @emeritusfilename.index('/emeritus-requests-received/')
        emeritus_url = ASF::SVN.svnurl('emeritus')
        command = "svn move #{@emeritusfilename} #{emeritus_url}"
        Wunderbar.warn("memstat.json.rb emeritus with command: #{command}")
        extra << ['move', @emeritusfilename, emeritus_url]
      end
    elsif @action == 'active'
      index = text.index(/^\s\*\)\s/, text.index(/^Active/))
      entry.sub! %r{\s*/\* deceased, .+?\*/},'' # drop the deceased comment if necessary
      # if emeritus file was found, move it to emeritus-reinstated
      if @emeritusfilename.index('//emeritus//')
        emeritus_reinstated_url = ASF::SVN.svnurl('emeritus-reinstated')
        command = "svn move #{@emeritusfilename} #{emeritus_reinstated_url}"
        extra << ['move', @emeritusfilename, emeritus_reinstated_url]
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
  pw = " --password #{env.password}" if env.password
  credentials = "--username #{env.user}#{pw}"
  command = "svn move #{credentials} -m \"#{message}\" #{@emeritusfilename} #{emeritus_rescinded_url}"
  _.system command
elsif @action == 'request_emeritus'
  # Create mail to secretary requesting emeritus
  FOUNDATION_URL = ASF::SVN.svnurl('foundation')
  EMERITUS_TEMPLATE_URL = File.join(FOUNDATION_URL, 'emeritus-request.txt').untaint
  template, err =
    ASF::SVN.svn('cat', EMERITUS_TEMPLATE_URL, {user: $USER.dup.untaint, password: $PASSWORD.dup.untaint})
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
  to "#{USERNAME}<#{USERMAIL}>"
# cc "secretary@apache.org"
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
