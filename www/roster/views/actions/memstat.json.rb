# get entry for @userid
entry = ASF::Person.find(@userid).members_txt(true)
raise Exception.new("unable to find member entry for #{userid}") unless entry

# identify file to be updated
members_txt = ASF::SVN['private/foundation/members.txt']

# construct commit message
message = "Move #{ASF::Person.find(@userid).member_name} to #{@action}"

# update members.txt
_svn.update members_txt, message: message do |dir, text|
  # remove user's entry
  text.sub! entry, ''

  # determine where to put the entry
  if @action == 'emeritus'
    index = text.index(/^\s\*\)\s/, text.index(/^Emeritus/))
  elsif @action == 'active'
    index = text.index(/^\s\*\)\s/, text.index(/^Active/))
  else
    raise Exception.new("invalid action #{action.inspect}")
  end

  # perform the insertion
  text.insert index, entry

  # save the updated text
  ASF::Member.text = text

  # return the updated (and normalized) text
  ASF::Member.text
end

# return updated committer info
_committer Committer.serialize(@userid, env)
