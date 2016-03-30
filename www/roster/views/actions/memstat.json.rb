# get entry for @userid
entry = ASF::Person.find(@userid).members_txt(true)
raise Exception.new("unable to find member entry for #{userid}") unless entry

# extract remote user's svn credentials
auth = ['--no-auth-cache', '--non-interactive']
if env.password
  auth += ['--username', env.user.untaint, '--password', env.password.untaint]
end

# perform all operations in a temporary directory
Dir.mktmpdir do |tmpdir|
  tmpdir.untaint

  # checkout out empty foundation directory
  system ['svn', 'checkout', '--quiet', '--depth', 'empty', auth,
    'https://svn.apache.org/repos/private/foundation', tmpdir]

  # fetch single file: members.txt
  system ['svn', 'update', '--quiet', auth, "#{tmpdir}/members.txt"]

  # read full members.txt
  text = File.read("#{tmpdir}/members.txt")

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

  # sort and save locally the updated text
  ASF::Member.text = ASF::Member.sort(text)

  # save the results to disk
  File.write("#{tmpdir}/members.txt", ASF::Member.text)

  # commit changes
  rc = system ['svn', 'commit', auth, "#{tmpdir}/members.txt",
    '--message', "Move #{ASF::Person.find(@userid).member_name} to #{action}"]
  raise Exception.new("svn commit failed") unless rc == 0
end

# return  updated committer info
_committer Committer.serialize('rubys', env)
