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
fileext = File.extname(@selected).downcase if @signature.empty?

# verify that an ICLA under that name doesn't already exist
if "#@filename#{fileext}" =~ /\w[-\w]*\.?\w*/
  icla = "#{ASF::SVN['private/documents/iclas']}/#@filename#{fileext}"
  if File.exist? icla.untaint
    _warn "documents/iclas/#@filename#{fileext} already exists"
  end
end

# extract/verify project
_extract_project

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
    if @signature.to_s.empty? or fileext != '.pdf'
      message.write_svn("#{dir}/iclas", @filename, @selected, @signature)
    else
      message.write_svn("#{dir}/iclas", @filename, 
        @selected => 'icla.pdf', @signature => 'icla.pdf.asc')
    end

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
    svn 'commit', dest, '-m', "ICLA for #{@pubname}"
  end
end

########################################################################
#                           email submitter                            #
########################################################################

# send confirmation email
task "email #@email" do
  # chose reply based on whether or not the project/userid info was provided
  if @user and not @user.empty?
    reply = 'icla-account-requested.erb'
  elsif @pmc
    @notify = "the #{@pmc.display_name} PMC has"

    if @podling
      @notify.sub! /has$/, "and the #{@podling.display_name} podling have"
    end

    reply = 'icla-pmc-notified.erb'
  else
    reply = 'icla.erb'
  end

  # build mail from template
  mail = message.reply(
    subject: "ICLA for #{@pubname}",
    from: @from,
    to: "#{@pubname.inspect} <#{@email}>",
    cc: [
      'secretary@apache.org',
      ("private@#{@pmc.mail_list}.apache.org" if @pmc), # copy pmc
      (@podling.private_mail_list if @podling) # copy podling
    ],
    body: template(reply)
  )

  # echo email
  form do
    _message mail.to_s
  end

  # deliver mail
  complete do
    mail.deliver!
  end
end

if @user and not @user.empty? and @pmc and not @votelink.empty?

  ######################################################################
  #                   acreq/new-account-reqs.txt                       #
  ######################################################################

  task "svn commit infra/acreq/new-account-reqs.txt" do
    # construct account request line
    @acreq ||= [
      @user,
      @pubname,
      @email,
      @pmc.name,
      @pmc.name,
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
      File.write dest, File.read(dest) + @acreq + "\n"

      # show the changes
      svn 'diff', dest

      # commit changes
      svn 'commit', dest, '-m', "#{@user} account request by #{env.user}"
    end
  end

  ######################################################################
  #                          email root@                               #
  ######################################################################

  task "email root@apache.org" do
    # build mail from template
    mail = Mail.new(template('acreq.erb'))

    # adjust copy lists
    cc = ["#{@pubname.inspect} <#{@email}>"]
    cc << "private@#{@pmc.mail_list}.apache.org" if @pmc # copy pmc
    cc << @podling.private_mail_list if @podling # copy podling
    mail.cc = cc.uniq.map {|email| email.dup.untaint}

    # untaint to email addresses
    mail.to = mail.to.map {|email| email.dup.untaint}

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
