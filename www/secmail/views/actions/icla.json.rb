#
# File an ICLA:
#  - add files to documents/iclas
#  - add entry to officers/iclas.txt
#  - send email
#

# extract message
message = Mailbox.find(@message)

# extract file extension
fileext = File.extname(@selected) if @signature.empty?

# extract/verify project
if @project and not @project.empty?
  pmc = ASF::Committee[@project]

  if not pmc
    podling = ASF::Podling.find(@project)

    if podling and not %w(graduated retired).include? podling.status
      pmc = ASF::Committee['incubator']
    end
  end

  if not pmc
    _warn "#{@project} is not an active PMC or podling"
  end
end

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
  cc = mail.cc # from the template
  cc += message.cc if message.cc # from the email message
  cc << "private@#{pmc.mail_list}.apache.org" if pmc # copy pmc
  cc << podling.private_mail_list if podling # copy podling
  mail.cc = cc.uniq
  mail.bcc = message.bcc - cc if message.bcc

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

if @user and not @user.empty? and pmc and not @votelink.empty?
  _task "svn commit infra/acreq/new-account-reqs.txt" do
    line = [
      @user,
      @pubname,
      @email,
      pmc.name,
      pmc.name,
      Date.today.strftime('%m-%d-%Y'),
      'yes',
      'yes',
      'no'
    ].join(';')

    Dir.mktmpdir do |dir|
      # checkout acreq directory
      _.system! 'svn', 'checkout', '--depth', 'files',
        'https://svn.apache.org/repos/infra/infrastructure/trunk/acreq', 
        "#{dir}/acreq",
        ['--non-interactive', '--no-auth-cache'],
        ['--username', env.user.untaint, '--password', env.password.untaint]

      # update new-account-reqs.txt
      dest = "#{dir}/acreq/new-account-reqs.txt"

      # update iclas.txt
      File.write dest, File.read(dest) + line + "\n"

      # show the changes
      _.system! 'svn', 'diff', dest

      # commit changes
      _.system! 'svn', 'commit', dest, '-m', 
        "#{@user} account request by #{env.user}",
        ['--non-interactive', '--no-auth-cache'],
        ['--username', env.user.untaint, '--password', env.password.untaint]
    end
  end

  # notify root@
  _task "email root@apache.org" do
    # obtain per-user information
    _personalize_email(env.user)

    # build mail from template
    template = File.expand_path('../../../templates/acreq.erb', __FILE__).untaint
    mail = Mail.new(ERB.new(File.read(template).untaint).result(binding))

    # adjust copy lists
    cc = mail.cc # from the template
    cc << "private@#{pmc.mail_list}.apache.org" if pmc # copy pmc
    cc << podling.private_mail_list if podling # copy podling
    mail.cc = cc.uniq

    # echo email
    _message mail.to_s

    # deliver mail
    mail.deliver!
  end
end
