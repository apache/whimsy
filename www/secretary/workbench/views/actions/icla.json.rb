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
fileext = File.extname(@selected).downcase

# verify that an ICLA under that name doesn't already exist
if "#@filename#{fileext}" =~ /\A\w[-\w]*\.?\w*\z/
  # Is there a matching ICLA? (returns first match, if any)
  file = ASF::ICLAFiles.match_claRef(@filename)
  if file
    _warn [["documents/iclas/#{file} already exists", ASF::SVN.svnpath!('iclas', file)]]
  else
    _icla = ASF::ICLA.find_by_email(@email.strip)
    if _icla
      _warn ["Email #{@email.strip} found in iclas.txt file:", _icla.as_line]
    else
      _icla = ASF::ICLA.find_matches(@realname.strip)
      if _icla.size > 0
        lines = []
        lines << "Found possible duplicate ICLAs:"
        _icla.each do |i|
          file = ASF::ICLAFiles.match_claRef(i.claRef)
          lines << [i.legal_name, ASF::SVN.svnpath!('iclas', file)]
        end
        _warn lines
      end
    end
  end
else
  _warn "#@filename#{fileext} does not appear to be a valid filename"
end

if @email.strip.end_with? '@apache.org'
  _warn "Cannot redirect email to an @apache.org address: #{@email.strip}"
end

# extract/verify project
_extract_project

# obtain per-user information
_personalize_email(env.user)

# determine if the user id requested is valid and available
@valid_user = (@user =~ /^[a-z][a-z0-9]{2,}$/)
@valid_user &&= !(ASF::ICLA.taken?(@user) or ASF::Mail.taken?(@user))

# initialize commit message
@document = "ICLA for #{@pubname}"

########################################################################
#                            document/iclas                            #
#                          officers/iclas.txt                          #
########################################################################

# write attachment (+ signature, if present) to the documents/iclas directory
task "svn commit documents/iclas/#@filename#{fileext} and iclas.txt" do

  # construct line to be inserted in iclas.txt
  @iclaline ||= [
    'notinavail',
    @realname.strip,
    @pubname.strip,
    @email.strip,
    "Signed CLA;#{@filename}"
  ].join(':')

  form do
    _input value: @selected, name: 'selected'

    if @signature and not @signature.empty?
      _input value: @signature, name: 'signature'
    end

    _input value: @iclaline, name: 'iclaline'

    _input value: @filename
  end

  complete do |dir|

    svn_multi('officers', 'iclas.txt', 'iclas', @selected, @signature, @filename, fileext, message, @document) do |input|
      # append entry to iclas.txt
      ASF::ICLA.sort(input + @iclaline + "\n")
    end

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
    if @podling # it looks like podlings also have PMC=Incubator
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

  @cttee = '(P)PMC'
  @cttee = "Apache #{@pmc.display_name} PMC" if @pmc
  # Process podling after PMC otherwise podling applicants are directed to IPMC
  @cttee = "Apache #{@podling.display_name} podling" if @podling
  # build mail from template

  # N.B. it appears that @from is not defined outside the task block
  _warn "Invalid From address '#{@from}'" unless @from =~ /\A("?[\s\w]+"?\s+<)?[-\w]+@apache\.org>?\z/

  mail = message.reply(
    subject: @document,
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
    if use_Bcc # Show Bcc
      _message "Bcc: #{mail[:bcc].decoded}\r\n#{mail.to_s}"
    else
      _message mail.to_s
    end
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

      rc = ASF::SVN.update(ASF::SVN.svnpath!('acreq', 'new-account-reqs.txt'),
        "#{@user} account request by #{env.user} for #{@pmc.name}",
        env, _, {diff: true}) do |tmpdir, contents|
          contents + @acreq + "\n"
      end
      raise RuntimeError.new("exit code: #{rc}") if rc != 0

    end
  end

  ######################################################################
  #                          email root@                               #
  ######################################################################

  task "email root@apache.org" do
    # build mail from template (already includes TO: root)
    mail = Mail.new(template('acreq.erb'))

    # adjust copy lists
    cc = ["#{@pubname.inspect} <#{@email}>"]
    cc << "private@#{@pmc.mail_list}.apache.org" if @pmc # copy pmc
    cc << @podling.private_mail_list if @podling # copy podling
    mail.cc = cc.uniq.map {|email| email}

    mail.from = @from

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
