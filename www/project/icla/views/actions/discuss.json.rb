require 'socket'
require 'net/http'
require 'pathname'
require 'json'
require 'mail'
require 'whimsy/lockfile'

# creates the discussion phase JSON file
# sends an email to the originator with the link

# Called from invite.js.rb POST
# expects the following variables to be set:
#  @pmc
#  @iclaemail
#  @iclaname
#  @proposalText
#  @discussComment
#  @proposer

# returns the following keys:
#  error
#  focus
#  token
#  userEmail
#  pmcEmail
#  subject
#  discussion
#  message

# find pmc and user information
# all ppmcs are also pmcs but not all pmcs are ppmcs

pmc = ASF::Committee.find(@pmc)
ppmc = ASF::Podling.find(@pmc)
pmc_type = if ppmc and ppmc.status == 'current' then 'PPMC' else 'PMC' end

user = ASF::Person.find(env.user)
user_email = user.id + '@apache.org'
subject = params['subject']

if ASF::Person.find_by_email(@iclaemail)
  _error "ICLA already on file for #{@iclaemail}"
  _focus :iclaemail
  return # cannot continue
end

begin
  Socket.getaddrinfo(@iclaemail[/@(.*)/, 1].untaint, 'smtp')

rescue
  _error 'Invalid domain name in email address'
  _focus :iclaemail
  return # cannot continue
end

# create the discussion object
timestamp = Time.now.utc.to_s
date = timestamp[0..9] # keep only the date
contributor = {:name => @iclaname, :email => @iclaemail}
comment = @proposalText + "\n" + @discussComment
comments = [{:member => @proposer, :timestamp => timestamp, :comment => comment}]
discussion = {
  :phase => 'discuss',
  :proposer => @proposer,
  :subject => subject,
  :project => @pmc,
  :contributor => contributor,
  :comments => comments,
  :votes => []  # make sure it is present
}

  # generate a token
token = pmc.name + '-' + date + '-' + Digest::MD5.hexdigest(@iclaemail)[0..5]

# save the discussion object to a file
file_name = '/srv/icla/' + token + '.json'

# important not to overwrite any existing files
err = LockFile.create_ex(file_name.untaint) do |f|
  f.write(JSON.pretty_generate(discussion))
end
if err
  if err.is_a? Errno::EEXIST
    _error 'There is already a file for that person!'
  else
    _error err.inspect
  end
  return # cannot continue
end

# add user and pmc emails to the response
_userEmail "#{user.public_name} <#{user.mail.first}>" if user
_pmcEmail "private@#{pmc.mail_list}.apache.org" if pmc

path = Pathname.new(env['REQUEST_URI']) + "../../?token=#{token}"
scheme = env['rack.url_scheme'] || 'https'
link = "#{scheme}://#{env['HTTP_HOST']}#{path}"
body_text = %{#{comment}

Use this link to discuss:
#{link}
}

# create the email to the user
mail = Mail.new do
  to user_email
  from user_email.untaint
  subject subject
  text_part do
    body body_text
  end
end
begin
  mail.deliver
rescue => e
  _error "Failed to send the mail: #{e}"
end

# add token and invitation to the response
_token token
_subject params['subject']
_discussion discussion
_message %{#{comment}
Use this link to continue the discussion:

#{link}
}
