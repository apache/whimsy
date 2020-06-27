# get entry for @userid
require 'wunderbar'
Wunderbar.warn('Memstat.json.rb action: ' + @action +
               ' for id: ' + @userid)
Wunderbar.warn('Memstat.json.rb request with emeritusfilename: ' + @emeritusfilename) if @emeritusfilename
Wunderbar.warn('Memstat.json.rb request with emerituspersonname: ' + @emerituspersonname) if @emerituspersonname

user = ASF::Person.find(@userid)
entry = user.members_txt(true)
raise Exception.new("unable to find member entry for #{userid}") unless entry
USERID = user.id
USERMAIL = "#{USERID}@apache.org".untaint
USERNAME = user.cn.untaint

# identify file to be updated
members_txt = File.join(ASF::SVN['foundation'], 'members.txt').untaint

# construct commit message
message = "Action #{@action} for #{ASF::Person.find(@userid).member_name}"

# only update members if needed
updmem = @action == 'emeritus' or @action == 'active' or @action == 'deceased'

# update members.txt only for secretary actions
ASF::SVN.multiUpdate members_txt, message, env, _ do |text|
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
      Wunderbar.warn "memstat.json.rb action emeritus commmand: #{command}"
      extra << ['move', @emeritusfilename, emeritus_url]
    end
  elsif @action == 'active'
    index = text.index(/^\s\*\)\s/, text.index(/^Active/))
    entry.sub! %r{\s*/\* deceased, .+?\*/},'' # drop the deceased comment if necessary
    # if emeritus file was found, move it to emeritus-reinstated
    if @emeritusfilename.index('//emeritus//')
      emeritus_reinstated_url = ASF::SVN.svnurl('emeritus-reinstated')
      command = "svn move #{@emeritusfilename} #{emeritus_reinstated_url}"
      Wunderbar.warn "memstat.json.rb action emeritus commmand: #{command}"
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
end if updmem #only update members.txt for secretary actions

if @action == 'rescind_emeritus'
  emeritus_rescinded_url = ASF::SVN.svnurl('emeritus-requests-rescinded')
  pw = " --password #{env.password}" if env.password
  credentials = "--username #{env.user}#{pw}"
  command = "svn move #{credentials} -m \"#{message}\" #{@emeritusfilename} #{emeritus_rescinded_url}"
  _.system command
  Wunderbar.warn ("memstat.json.rb rescind_emeritus command: #{command}")
elsif @action == 'request_emeritus'
  # Create mail to secretary requesting emeritus
  FOUNDATION_URL = ASF::SVN.svnurl('foundation')
  Wunderbar.warn("Memstat.json.rb foundation url: #{FOUNDATION_URL}")
  EMERITUS_TEMPLATE_URL = File.join(FOUNDATION_URL, 'emeritus-request.txt').untaint
  Wunderbar.warn("Memstat.json.rb emeritus template url: #{EMERITUS_TEMPLATE_URL}")
  template, err =
    ASF::SVN.svn('cat', EMERITUS_TEMPLATE_URL, {user: $USER, password: $PASSWORD})
  raise RuntimeError.new("Failed to read emeritus-request.txt" + err) unless template
  centered_name = "#{USERNAME}".center(55, '_')
  centered_date ="#{timestamp}".center(55, '_')
  signed_request = template
    .gsub('Full name: _______________________________________________________',
          ('Full name: ' + centered_name))
    .gsub('Signed: ________________________________',
          'Signed: ______________Whimsy www/roster validated user____________')
    .gsub('Date: ___________________',
          ('Date: ' + centered_date))

  ASF::Mail.configure
  mail = Mail.new do
  to "#{USERNAME}<#{USERMAIL}>"
# cc "secretary@apache.org"
    from "#{USERMAIL}"
    subject "Emeritus request from #{USERNAME}"
    body "Emeritus request is attached."
  end
  mail.attachments["#{USERID}.txt"] = signed_request
  mail.deliver!
elsif @action == 'request_reinstatement'
  Wunderbar.warn "memstat.json.rb request reinstatement"
  ASF::Mail.configure
  mail = Mail.new do
    to "secretary@apache.org"
    cc "#{USERNAME}<#{USERMAIL}>"
    from "#{USERMAIL}"
    subject "Emeritus reinstatement request from #{USERNAME}"
    body "I respectfully request reinstatement to full membership.

      Regards,
      #{USERNAME}"
  end
  mail.deliver!
end

# return updated committer info
_committer Committer.serialize(@userid, env)
