#
# File an ICLA:
#  - add files to documents/iclas
#  - add entry to officers/iclas.txt
#  - send email
#

message = Mailbox.find(@message)
iclas = ASF::SVN['private/documents/iclas']

# extract file extension
fileext = File.extname(@selected) if @signature.empty?

# write attachment (+ signature, if present) to the documents/iclas directory
_task "svn commit documents/iclas/#@filename#{fileext}" do
  Dir.mktmpdir do |dir|
    # checkout empty directory
    _.system! 'svn', 'checkout', '--depth', 'empty',
      'https://svn.apache.org/repos/private/documents/iclas', "#{dir}/iclas",
      ['--non-interactive', '--no-auth-cache'],
      ['--username', env.user.untaint, '--password', env.password.untaint]

    # create/add file(s)
    dest = message.write_svn("#{dir}/iclas", @filename, @selected, @signature)

    # stub for now
    _.system 'svn', 'status', "#{dir}/iclas"
  end
end

# insert line into iclas.txt
_task "svn commit foundation/officers/iclas.txt" do
  # construct line to be inserted
  insert = [
    'notinavail',
    @realname.strip,
    @pubname.strip,
    @email.strip,
    "Signed CLA;#{@filename}"
  ].join(':')

  Dir.mktmpdir do |dir|
    # checkout empty officers directory
    _.system! 'svn', 'checkout', '--depth', 'empty',
      'https://svn.apache.org/repos/private/foundation/officers', 
      "#{dir}/officers",
      ['--non-interactive', '--no-auth-cache'],
      ['--username', env.user.untaint, '--password', env.password.untaint]

    # retrieve iclas.txt
    dest = "#{dir}/officers/iclas.txt"
    _.system! 'svn', 'update', dest,
      ['--non-interactive', '--no-auth-cache'],
      ['--username', env.user.untaint, '--password', env.password.untaint]

    # update iclas.txt
    iclas_txt = ASF::ICLA.sort(File.read(dest) + insert + "\n")
    File.write dest, iclas_txt

    # show the changes
    _.system 'svn', 'diff', dest
  end
end

# send confirmation email
_task "email #@email" do
end

{result: "stub for ICLA, filename: #{@filename}"}
