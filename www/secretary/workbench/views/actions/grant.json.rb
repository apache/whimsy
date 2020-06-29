#
# File an ICLA:
#  - add files to documents/grants
#  - add entry to officers/grants.txt
#  - respond to original email
#

# extract message
message = Mailbox.find(@message)

# extract file extension
fileext = File.extname(@selected).downcase if @signature.empty?

grant = "#@filename#{fileext}"

# verify that a grant under that name doesn't already exist
if grant =~ /^\w[-\w]*\.?\w*$/
  if ASF::GrantFiles.exist?(grant.untaint)
    _warn "documents/grants/#{grant} already exists"
  end
else
  # Should not be possible, as form checks for: '[a-zA-Z][-\w]+(\.[a-z]+)?'
  _warn "#{grant} is not a valid file name"
end

# extract/verify project
_extract_project

# obtain per-user information
_personalize_email(env.user)

# initialize commit message
@document = "Software Grant from #{@company}"

########################################################################
#                           document/grants                            #
########################################################################

# write attachment (+ signature, if present) to the documents/grants directory
task "svn commit documents/grants/#@filename#{fileext}" do
  form do
    _input value: @selected, name: 'selected'

    if @signature and not @signature.empty?
      _input value: @signature, name: 'signature'
    end
  end

  complete do |dir|
    # checkout empty directory
    svn 'checkout', '--depth', 'empty',
      ASF::SVN.svnurl('grants'), "#{dir}/grants"

    # create/add file(s)
    dest = message.write_svn("#{dir}/grants", @filename, @selected, @signature)

    # Show files to be added
    svn 'status', "#{dir}/grants"

    # commit changes
    svn 'commit', "#{dir}/grants/#{@filename}#{fileext}", '-m', @document
  end
end

########################################################################
#                         officers/grants.txt                          #
########################################################################

# insert line into grants.txt
task "svn commit foundation/officers/grants.txt" do
  # construct line to be inserted
  @grantlines = "#{@company.strip}" +
    "\n  file: #{@filename}#{fileext}" +
    "\n  for: #{@description.strip.gsub(/\r?\n\s*/,"\n       ")}"

  form do
    _textarea @grantlines, name: 'grantlines', 
      rows: @grantlines.split("\n").length
  end

  complete do |dir|
    # checkout empty officers directory
    svn 'checkout', '--depth', 'empty',
      ASF::SVN.svnurl!('officers'), 
      File.join(dir, 'officers')

    # retrieve grants.txt
    dest = File.join(dir, 'officers', 'grants.txt')
    svn 'update', dest

    # update grants.txt
    marker = "\n# registering.  documents on way to Secretary.\n"
    File.write dest,
      File.read(dest).split(marker).insert(1, "\n#{@grantlines}\n", marker).join

    # show the changes
    svn 'diff', dest

    # commit changes
    svn 'commit', dest, '-m', @document
  end
end

########################################################################
#                           email submitter                            #
########################################################################

# send confirmation email
task "email #@email" do
  # build mail from template
  mail = message.reply(
    subject: @document,
    from: @from,
    to: "#{@name.inspect} <#{@email}>",
    cc: [
      'secretary@apache.org',
      ("private@#{@pmc.mail_list}.apache.org" if @pmc), # copy pmc
      (@podling.private_mail_list if @podling) # copy podling
    ],
    body: template('grant.erb')
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
