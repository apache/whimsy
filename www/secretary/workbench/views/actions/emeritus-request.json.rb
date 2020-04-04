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
  if names.include? @filename.untaint
    _warn "documents/emeritus-requests-received/#{@filename} already exists"
  elsif names.include? emeritus_request.untaint
    _warn "documents/emeritus-requests-received/#{emeritus_request} already exists"
  end
else
  _warn "#{emeritus_request} is not a valid file name"
end

# obtain per-user information
_personalize_email(env.user)

task 'hello, world!' do
  form do
    _message message.to_s
  end

  complete do
    _message 'TODO'
  end
end
