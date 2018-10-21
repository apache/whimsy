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
  icladir = "#{ASF::SVN['iclas']}/#@filename" # also check for directory
  if File.exist? icladir.untaint
    _warn "documents/iclas/#@filename already exists"
  end
  icla = "#{ASF::SVN['iclas']}/#@filename#{fileext}"
  if File.exist? icla.untaint
    _warn "documents/iclas/#@filename#{fileext} already exists"
  end
end

# extract/verify project
_extract_project

# obtain per-user information
_personalize_email(env.user)

# determine if the user id requested is valid and avaliable
@valid_user = (@user =~ /^[a-z][a-z0-9]{2,}$/)
@valid_user &&= !(ASF::ICLA.taken?(@user) or ASF::Mail.taken?(@user))

########################################################################
#                            document/iclas                            #
########################################################################

# write attachment (+ signature, if present) to the documents/iclas directory
task "svn commit documents/iclas/#@filename#{fileext}" do
  form do
    _input value: URI.decode(@selected), name: 'selected'

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
      message.write_svn("#{dir}/iclas", @filename, URI.decode(@selected), @signature)
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
  # set up notify for body of message
  if @pmc
    @notify = "the #{@pmc.display_name} PMC has"
    if @podling
      @notify.sub! /has$/, "and the #{@podling.display_name} podling have"
    end
  end

  # choose reply message based on whether or not the project/userid info was provided
  use_Bcc = false # should we use Bcc for the secretary?
  if @user and not @user.empty?
    if @valid_user
      # pmc vote verified and id is valid
      reply = 'icla-account-requested.erb'
      use_Bcc = true # it's now up to the (P)PMC
    else
      # pmc vote verified but id is invalid
      reply = 'icla-invalid-id.erb'
      use_Bcc = true # it's now up to the (P)PMC
    end
  elsif @pmc
    # no pmc vote but pmc was requested to be notified or user is active on project
    reply = 'icla-pmc-notified.erb'
    use_Bcc = true # it's now up to the (P)PMC
  else
    # no evidence of project activity by the submitter
    reply = 'icla.erb'
  end

  # build mail from template
  mail = message.reply(
    subject: "ICLA for #{@pubname}",
    from: @from,
    to: "#{@pubname.inspect} <#{@email}>",
    cc: [
      ('secretary@apache.org' unless use_Bcc),
      ("private@#{@pmc.mail_list}.apache.org" if @pmc), # copy pmc
      (@podling.private_mail_list if @podling) # copy podling
    ],
    bcc: [ ('secretary@apache.org' if use_Bcc)],
    body: template(reply)
  )

  # set Reply-To header to podling or pmc private mailing list 
  if @podling
    mail.header['Reply-To'] = @podling.private_mail_list
  elsif @pmc
    mail.header['Reply-To'] = "private@#{@pmc.mail_list}.apache.org"
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

if @valid_user and @pmc and not @votelink.empty?

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
      svn 'commit', dest, '-m', "#{@user} account request by #{env.user} for #{@pmc.name}"
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
