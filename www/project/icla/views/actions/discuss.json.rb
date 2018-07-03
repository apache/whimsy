require 'socket'
require 'net/http'
require 'pathname'
require 'json'
require 'mail'
require 'whimsy/lockfile'

# find pmc and user information
# all ppmcs are also pmcs but not all pmcs are ppmcs

pmc = ASF::Committee.find(@pmc)
ppmc = ASF::Podling.find(@pmc)
pmc_type = if ppmc and ppmc.status == 'current' then 'PPMC' else 'PMC' end

user = ASF::Person.find(env.user)
user_email = user.id + '@apache.org'
subject = params['subject']

begin
  Socket.getaddrinfo(@iclaemail[/@(.*)/, 1].untaint, 'smtp')

  if ASF::Person.find_by_email(@iclaemail)
    _error "ICLA already on file for #{@iclaemail}"
  end
rescue
  _error 'Invalid domain name in email address'
  _focus :iclaemail
end
# create the discussion object
date = Time.now.to_date.to_s
contributor = {:name => @iclaname, :email => @iclaemail}
comment = @proposalText + "\n" + @discussComment
comments = [{:member => @proposer, :timestamp => date, :comment => comment}]
discussion = {
  :phase => 'discuss',
  :proposer => @proposer,
  :subject => subject,
  :project => @pmc,
  :contributor => contributor,
  :comments => comments
}

  # generate a token
token = pmc.name + '-' + date + '-' + Digest::MD5.hexdigest(@iclaemail)[0..5]

# save the discussion object to a file
file_name = '/srv/icla/' + token + '.json'

# important not to overwrite any existing files
if LockFile.create_ex(file_name.untaint) do |f| 
  f.write(JSON.pretty_generate(discussion))
  end
else
  _error 'There is already a file for that person!'
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

# create the email to the pmc
mail = Mail.new do
  to user_email
  from user_email.untaint
  subject subject
  text_part do
    body body_text
  end
end
mail.deliver

# add token and invitation to the response
_token token
_subject params['subject']
_discussion discussion
_message %{#{comment}
Use this link to continue the discussion:

#{link}
}
