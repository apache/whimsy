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
  system ['svn', 'checkout', '--quiet', '--depth', 'empty', *[auth],
    'https://svn.apache.org/repos/private/foundation', tmpdir]

  # fetch single file: members.txt
  system ['svn', 'update', '--quiet', *[auth], "#{tmpdir}/members.txt"]

  # read full members.txt
  text = File.read("#{tmpdir}/members.txt")

  # remove user's entry
  text.sub! entry, ''

  # determine where to put the entry
  if @action == 'emeritus'
    index = text.index(/^\s\*\)\s/, text.index(/^Emeritus/))
  elsif @action == 'emeritus'
    index = text.index(/^\s\*\)\s/, text.index(/^Active/))
  else
    raise Exception.new("invalid action #{action.inspect}")
  end

  # perform the insertion
  text.insert index, entry

  # sort the text and save the result to disk
  File.write("#{tmpdir}/members.txt", ASF::Member.sort(text))

  # for now, just show what would have been committed
  system ['svn', 'diff', "#{tmpdir}/members.txt"]
end

# return  updated committer info
_committer Committer.serialize('rubys', env)
