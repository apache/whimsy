#
# File an ICLA:
#  - add files to documents/cclas
#  - add entry to officers/cclas.txt
#  - respond to original email
#

# extract message
message = Mailbox.find(@message)

# extract file extension
fileext = File.extname(@selected).downcase if @signature.empty?

# verify that a CCLA under that name doesn't already exist
if "#@filename#{fileext}" =~ /\w[-\w]*\.?\w*/
  ccla = "#{ASF::SVN['private/documents/cclas']}/#@filename#{fileext}"
  if File.exist? ccla.untaint
    _warn "documents/cclas/#@filename#{fileext} already exists"
  end
end

# extract/verify project
_extract_project

# obtain per-user information
_personalize_email(env.user)

# initialize commit message
@document = "CCLA from #{@company}"

########################################################################
#                            document/cclas                            #
########################################################################

# write attachment (+ signature, if present) to the documents/cclas directory
task "svn commit documents/cclas/#@filename#{fileext}" do
  form do
    _input value: @selected, name: 'selected'

    if @signature and not @signature.empty?
      _input value: @signature, name: 'signature'
    end
  end

  complete do |dir|
    # checkout empty directory
    svn 'checkout', '--depth', 'empty',
      'https://svn.apache.org/repos/private/documents/cclas', "#{dir}/cclas"

    # create/add file(s)
    dest = message.write_svn("#{dir}/cclas", @filename, @selected, @signature)

    # Show files to be added
    svn 'status', "#{dir}/cclas"

    # commit changes
    svn 'commit', "#{dir}/cclas/#{@filename}#{fileext}", '-m', @document
  end
end

########################################################################
#                          officers/cclas.txt                          #
########################################################################

# insert line into iclas.txt
task "svn commit foundation/officers/cclas.txt" do
  # construct line to be inserted
  @cclalines = "notinavail:" + @company.strip

  unless @contact.empty?
    @cclalines += " - #{@contact.strip}"
  end

  @cclalines += ":#{@email.strip}:Signed Corp CLA"

  unless @employees.empty?
    @cclalines += " for #{@employees.strip.gsub(/\s*\n\s*/, ', ')}"
  end

  unless @product.empty?
    @cclalines += " for #{@product.strip}"
  end

  form do
    _input value: @cclalines, name: 'cclalines'
  end

  complete do |dir|
    # checkout empty officers directory
    svn 'checkout', '--depth', 'empty',
      'https://svn.apache.org/repos/private/foundation/officers', 
      "#{dir}/officers"

    # retrieve cclas.txt
    dest = "#{dir}/officers/cclas.txt"
    svn 'update', dest

    # update cclas.txt
    File.write dest, File.read(dest) + @cclalines + "\n"

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
    to: "#{@contact.inspect} <#{@email}>",
    cc: [
      'secretary@apache.org',
      ("private@#{@pmc.mail_list}.apache.org" if @pmc), # copy pmc
      (@podling.private_mail_list if @podling) # copy podling
    ],
    body: template('ccla.erb')
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
