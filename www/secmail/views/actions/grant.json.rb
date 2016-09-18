#
# File an ICLA:
#  - add files to documents/grants
#  - add entry to officers/grants.txt
#  - respond to original email
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
      'https://svn.apache.org/repos/private/documents/grants', "#{dir}/grants"

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
      'https://svn.apache.org/repos/private/foundation/officers', 
      "#{dir}/officers"

    # retrieve grants.txt
    dest = "#{dir}/officers/grants.txt"
    svn 'update', dest

    # update grants.txt
    File.write dest, File.read(dest) + @grantlines + "\n"

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
    from: @from,
    cc: [
      'secretary@apache.org',
      ("private@#{pmc.mail_list}.apache.org" if pmc), # copy pmc
      (podling.private_mail_list if podling) # copy podling
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
