#
# File an ICLA:
#  - add files to documents/iclas
#  - add entry to officers/iclas.txt
#  - respond to original email
#  - [optional] add entry to new-account-reqs.txt
#  - [optional] send email to root@
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

# obtain per-user information
_personalize_email(env.user)

########################################################################
#                            document/iclas                            #
########################################################################

# write attachment (+ signature, if present) to the documents/iclas directory
task "svn commit documents/iclas/#@filename#{fileext}" do
  form do
    _input value: @selected, name: 'selected'

    if @signature and not @signature.empty?
      _input value: @signature, name: 'signature'
    end
  end

  complete do |dir|
    # checkout empty directory
    svn 'checkout', '--depth', 'empty',
      'https://svn.apache.org/repos/private/documents/iclas', "#{dir}/iclas"

    # create/add file(s)
    dest = message.write_svn("#{dir}/iclas", @filename, @selected, @signature)

    # Show files to be added
    svn 'status', "#{dir}/iclas"

    # commit changes
    svn 'commit', "#{dir}/iclas/#{@filename}#{fileext}",
      '-m', "ICLA from #{@pubname}"
  end
end

########################################################################
#                          officers/iclas.txt                          #
########################################################################

# insert line into iclas.txt
task "svn commit foundation/officers/iclas.txt" do
  # construct line to be inserted
  @iclaline ||= [
    'notinavail',
    @realname.strip,
    @pubname.strip,
    @email.strip,
    "Signed CLA;#{@filename}"
  ].join(':')

  form do
    _input value: @iclaline, name: 'iclaline'
  end

  complete do |dir|
    # checkout empty officers directory
    svn 'checkout', '--depth', 'empty',
      'https://svn.apache.org/repos/private/foundation/officers', 
      "#{dir}/officers"

    # retrieve iclas.txt
    dest = "#{dir}/officers/iclas.txt"
    svn 'update', dest

    # update iclas.txt
    iclas_txt = ASF::ICLA.sort(File.read(dest) + @iclaline + "\n")
    File.write dest, iclas_txt

    # show the changes
    svn 'diff', dest

    # commit changes
    svn 'commit', dest, '-m', "ICLA from #{@pubname}"
  end
end

########################################################################
#                           email submitter                            #
########################################################################

# send confirmation email
task "email #@email" do
  # build mail from template
  mail = Mail.new(template('icla.erb'))

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
  form do
    _message mail.to_s
  end

  # deliver mail
  complete do
    mail.deliver!
  end
end

if @user and not @user.empty? and pmc and not @votelink.empty?

  ######################################################################
  #                   acreq/new-account-reqs.txt                       #
  ######################################################################

  task "svn commit infra/acreq/new-account-reqs.txt" do
    # construct account request line
    @acreq ||= [
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

    form do
      _input value: @acreq, name: 'acreq'
    end

    complete do |dir|
      # checkout acreq directory
      svn 'checkout', '--depth', 'files',
        'https://svn.apache.org/repos/infra/infrastructure/trunk/acreq', 
        "#{dir}/acreq"

      # update new-account-reqs.txt
      dest = "#{dir}/acreq/new-account-reqs.txt"

      # update iclas.txt
      File.write dest, File.read(dest) + line + "\n"

      # show the changes
      svn 'diff', dest

      # commit changes
      svn 'commit', dest, '-m', 
        "#{@user} account request by #{env.user}"
    end
  end

  ######################################################################
  #                          email root@                               #
  ######################################################################

  task "email root@apache.org" do
    # build mail from template
    mail = Mail.new(template('acreq.erb'))

    # adjust copy lists
    cc = mail.cc # from the template
    cc << "private@#{pmc.mail_list}.apache.org" if pmc # copy pmc
    cc << podling.private_mail_list if podling # copy podling
    mail.cc = cc.uniq

    # echo email
    form do
      _message mail.to_s
    end

    # deliver mail
    complete do
      mail.deliver!
    end
  end
end
