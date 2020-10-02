#
# Files a member emeritus request
# - add files to documents/emeritus-requests-received
# - (?) add entry to some file
# - respond to original email
#

# extract message
message = Mailbox.find(@message)

# extract file extension
fileext = File.extname(@selected).downcase if @signature.empty?

# verify that a membership emeritus request under that name stem doesn't already exist
emeritus_request = "#{@filename}#{fileext}"
if emeritus_request =~ /\A\w[-\w]*\.?\w*\z/ # check taint requirements
  names = ASF::EmeritusRequestFiles.listnames
  if names.include? @filename
    _warn "documents/emeritus-requests-received/#{@filename} already exists"
  elsif names.include? emeritus_request
    _warn "documents/emeritus-requests-received/#{emeritus_request} already exists"
  end
else
  _warn "#{emeritus_request} is not a valid file name"
end

# obtain per-user information
_personalize_email(env.user)

member = ASF::Person.find(@availid)
@name = member.public_name
summary = "Emeritus Request from #{@name}"

# file the emeritus request in svn
task "svn commit documents/emeritus-requests-received/#{emeritus_request}" do
  form do
    _input name: 'selected', value: @selected
    unless @signature.empty?
      _input name: 'signature', value: @signature
    end
  end

  complete do |dir|
    # checkout empty directory
    svn! 'checkout', [ASF::SVN.svnurl('emeritus-requests-received'), dir], {depth: 'empty'}

    # extract the attachments and add to the workspace
    message.write_svn(dir, @filename, @selected, @signature)

    svn! 'status', dir
    svn! 'commit', dir, {msg: summary}
  end
end

# respond to the member with acknowledgement
task "email #{message.from}" do
  mail = message.reply(
      subject: summary,
      from: @from,
      to: "#{@name.inspect} <#{message.from}>",
      cc: 'secretary@apache.org',
      body: template('emeritus-request.erb')
  )

  form do
    _message mail.to_s
  end

  complete do
    mail.deliver!
  end
end
