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

ccla = "#@filename#{fileext}"

# verify that a CCLA under that name doesn't already exist
if ccla =~ /\A\w[-\w]*\.?\w*\z/
  if ASF::CCLAFiles.exist?(ccla)
    _warn "documents/cclas/#{ccla} already exists"
  end
else
  # Should not be possible, as form checks for: '[a-zA-Z][-\w]+(\.[a-z]+)?'
  _warn "#{ccla} is not a valid file name"
end

# extract/verify project
_extract_project

# obtain per-user information
_personalize_email(env.user)

# initialize commit message
@document = "CCLA from #{@company}"

########################################################################
#              document/cclas and cclas.txt                            #
########################################################################

task "svn commit documents/cclas/#@filename#{fileext} and update cclas.txt" do

  # construct line to be inserted in cclas.txt
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
    _input value: @selected, name: 'selected'

    if @signature and not @signature.empty?
      _input value: @signature, name: 'signature'
    end

    _input value: @cclalines, name: 'cclalines'
  end

  complete do |dir|

    svn_multi('officers', 'cclas.txt', 'cclas', @selected, @signature, @filename, fileext, message, @document) do |input|
      # append entry to cclas.txt
      input + @cclalines + "\n"
    end

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
