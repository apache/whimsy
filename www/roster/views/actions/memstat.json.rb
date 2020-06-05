# get entry for @userid
require 'wunderbar'
Wunderbar.warn('Memstat.json.rb action: ' + @action +
               ' for id: ' + @userid)
Wunderbar.warn('Memstat.json.rb request with emeritusfilename: ' + @emeritusfilename) if @emeritusfilename
Wunderbar.warn('Memstat.json.rb request with emerituspersonname: ' + @emerituspersonname) if @emerituspersonname
Wunderbar.warn('Memstat.json.rb request with emeritusemail: ' + @emeritusemail) if @emeritusemail

entry = ASF::Person.find(@userid).members_txt(true)
raise Exception.new("unable to find member entry for #{userid}") unless entry

# identify file to be updated
members_txt = File.join(ASF::SVN['foundation'], 'members.txt')

# construct commit message
message = "Move #{ASF::Person.find(@userid).member_name} to #{@action}"

# only update members if needed
updmem = @action == 'emeritus' or @action == 'active' or @action == 'deceased'

# update members.txt only for secretary actions
_svn.multiUpdate members_txt, message: message, env, _  do |dir, text|
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
      command = "svn mv #{@emeritusfilename} #{emeritus_url}"
      Wunderbar.warn "memstat.json.rb action emeritus commmand: #{command}"
      extra << ['mv', @emeritusfilename, emeritus_url]
    end
  elsif @action == 'active'
    index = text.index(/^\s\*\)\s/, text.index(/^Active/))
    entry.sub! %r{\s*/\* deceased, .+?\*/},'' # drop the deceased comment if necessary
    # if emeritus file was found, move it to emeritus-reinstated
    if @emeritusfilename.index('/emeritus/')
      emeritus_reinstated_url = ASF::SVN.svnurl('emeritus-reinstated')
      command = "svn mv #{@emeritusfilename} #{emeritus_reinstated_url}"
      Wunderbar.warn "memstat.json.rb action emeritus commmand: #{command}"
    end
  elsif @action == 'deceased'
    index = text.index(/^\s\*\)\s/, text.index(/^Deceased/))
    entry.sub! %r{\n}, " /* deceased, #{@dod} */\n" # add the deceased comment
#  else
#    raise Exception.new("invalid action #{action.inspect}")
  end

  # perform the insertion
  text.insert index, entry

  # save the updated text
  ASF::Member.text = text

  # return the updated (and normalized) text and extra svn command
  [ASF::Member.text, extra]
end if updmem #only update members.txt for secretary actions

if @action == 'rescind_emeritus'
  emeritus_rescinded_url = ASF::SVN.svnurl('emeritus')
  command = "svn mv #{@emeritusfilename} #{emeritus_rescinded_url}; svn commit -m \"#{message}\""
  Wunderbar.warn ("memstat.json.rb rescind_emeritus command: #{command}")
elsif @action == 'request_emeritus'
  # TODO send email to secretary requesting emeritus
  Wunderbar.warn ("memstat.json.rb request emeritus")
elsif @action == 'request_reinstatement'
  # TODO send email to secretary, cc: OP attaching reinstatement request form
  Wunderbar.warn "memstat.json.rb request reinstatement"
end

# return updated committer info
_committer Committer.serialize(@userid, env)
