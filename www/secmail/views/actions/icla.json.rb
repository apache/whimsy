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

    # Show files to be added
    _.system 'svn', 'status', "#{dir}/iclas"

    # commit changes
    _.system! 'svn', 'commit', "#{dir}/iclas/#{@filename}#{fileext}",
      '-m', "ICLA from #{@pubname}",
      ['--non-interactive', '--no-auth-cache'],
      ['--username', env.user.untaint, '--password', env.password.untaint]
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
    _.system! 'svn', 'diff', dest

    # commit changes
    _.system! 'svn', 'commit', dest, '-m', "ICLA from #{@pubname}",
      ['--non-interactive', '--no-auth-cache'],
      ['--username', env.user.untaint, '--password', env.password.untaint]

  end
end

# send confirmation email
_task "email #@email" do
  # obtain per-user information
  _personalize_email(env.user)

  # build mail from template
  template = File.expand_path('../../../templates/icla.erb', __FILE__).untaint
  mail = Mail.new(ERB.new(File.read(template).untaint).result(binding))

  # adjust copy lists
  mail.cc = (mail.cc + message.cc).uniq if message.cc
  mail.bcc = message.bcc - mail.cc if message.bcc

  # add reply info
  mail.in_reply_to = message.id
  mail.references = message.id
  if message.subject =~ /^re:\s/i
    mail.subject = message.subject
  else
    mail.subject = 'Re: ' + message.subject
  end

  # echo email
  _message mail.to_s

  # deliver mail
  mail.deliver!
end
