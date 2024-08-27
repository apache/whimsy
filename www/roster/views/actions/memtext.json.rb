# validate new entry
new_entry = @entry.strip
#ensure required entries are present as separate lines
unless new_entry =~ %r{^\s*Forms on File: ASF Membership Application$} and
       new_entry =~ %r{^\s*Avail ID: #{@userid}$}
  raise Exception.new('Missing required item: Avail ID and/or Forms, or Avail ID does not match')
end

# get existing entry for @userid
old_entry = ASF::Person.find(@userid).members_txt(true)
raise Exception.new("unable to find member entry for #{userid}") unless old_entry

# identify file to be updated
members_txt = File.join(ASF::SVN['foundation'], 'members.txt')

# construct commit message
message = "Update entry for #{ASF::Person.find(@userid).member_name}"

# update members.txt
_svn.update members_txt, message: message do |dir, text|
  # replace entry
  unless text.sub! old_entry, " *) #{new_entry}\n\n" # e.g. if the workspace was out of date
    raise Exception.new('Failed to replace existing entry -- try refreshing')
  end

  # save the updated text
  ASF::Member.text = text

  # return the updated (and normalized) text
  ASF::Member.text
end

# return updated committer info
_committer Committer.serialize(@userid, env)
