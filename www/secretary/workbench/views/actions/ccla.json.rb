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
  if ASF::CCLAFiles.exist?(ccla.untaint)
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
    ASF::SVN.multiUpdate_(ASF::SVN.svnpath!('officers', 'cclas.txt'), @document, env, _) do |text|

      extras = []
      # write the file(s)
      dest = message.write_att(@selected, @signature)

      if dest.size > 1 # write to a container directory
        container = ASF::SVN.svnpath!('cclas', @filename)
        extras << ['mkdir', container]
        dest.each do |name, path|
          extras << ['put', path, File.join(container, name)]
        end
      else
        name, path = dest.flatten
        extras << ['put', path, ASF::SVN.svnpath!('cclas',"#{@filename}#{fileext}")]
      end

      [text + @cclalines + "\n", extras]
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
