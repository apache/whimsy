#
# Files a member withdrawal request
# - add files to documents/withdrawn/pending/
# - respond to original email
#

# extract message
message = Mailbox.find(@message)

# extract file extension
fileext = File.extname(@selected).downcase if @signature.empty?

# verify that a membership withdrawal request under that name stem doesn't already exist
withdrawal_request = "#{@filename}#{fileext}"
if @filename =~ /\A[a-z][-a-z0-9]+\z/ # check name is valid as availid
  withdrawal_pending = ASF::SVN.svnpath!('withdrawn-pending')
  list, err = ASF::SVN.listnames(withdrawal_pending, env.user, env.password)
  unless list
    _warn err
    list = []
  end
  names = list.select{|x| x.start_with? "#{@filename}."}
  if names.size > 0
    _warn "#{withdrawal_pending}/#{names.first} already exists"
  end
else
  _warn "#{withdrawal_request} is not a valid file name (must be valid as an availid)"
end

# obtain per-user information
_personalize_email(env.user)

member = ASF::Person.find(@availid)
@name = member.public_name
summary = "Withdrawal Request from #{@name}"

# file the withdrawal request in svn
task "svn commit #{withdrawal_pending}/#{withdrawal_request}" do
  form do
    _input name: 'selected', value: @selected
    unless @signature.empty?
      _input name: 'signature', value: @signature
    end
  end

  complete do |dir|
    # checkout empty directory
    svn! 'checkout', [withdrawal_pending, dir], {depth: 'empty'}

    # extract the attachments and add to the workspace
    message.write_svn(dir, @filename, @selected, @signature)

    svn! 'status', dir
    svn! 'commit', dir, {msg: summary}
    ASF::WithdrawalRequestFiles.refreshnames(true, env) # update the listing
  end
end

# respond to the member with acknowledgement
task "email #{message.from}" do
  mail = message.reply(
      subject: summary,
      from: @from,
      to: "#{@name.inspect} <#{message.from}>",
      cc: 'secretary@apache.org',
      body: template('withdrawal-request.erb')
  )

  form do
    _message mail.to_s
  end

  complete do
    mail.deliver!
  end
end
