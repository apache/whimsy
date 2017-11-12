require 'socket'
require 'net/http'
require 'pathname'

# find pmc and user information
# all ppmcs are also pmcs but not all pmcs are ppmcs

pmc = ASF::Committee.find(@pmc)
ppmc = ASF::Podling.find(@pmc)
pmc_type = if ppmc then 'PPMC' else 'PMC' end

user = ASF::Person.find(env.user)

# prototype mail text
prototype_contributor =
"Based on your contributions to #{pmc.name}, you are invited to submit an ICLA
to The Apache Software Foundation, using the following form. Please see
http://apache.org/licenses for details.
"

prototype_committer =
"Congratulations! The #{pmc.name} #{pmc_type} hereby offers you committer privileges
to the #{pmc.name} project.

These privileges are offered on the understanding that you'll use them
reasonably and with common sense. We like to work on trust rather than
unnecessary constraints.

Being a committer enables you to more easily make changes without needing to
go through the patch submission process.

Being a committer does not require you to participate any more than you already
do. It does tend to make one even more committed ;-) You willprobably find that
you spend more time here.

Of course, you can decline and instead remain as a contributor, participating
as you do now.

This personal invitation is a chance for you to accept or decline in private.
Either way, please let us know in reply to the private@#{pmc.name}.apache.org
address only.
"

prototype_pmc =
"You are also invited to become a member of the #{pmc.name} #{pmc_type}.
Being a #{pmc_type} member enables you to help guide the direction of the project.
If you accept, you will have binding votes on releases and new committers.
"

# validate email address
begin
  Socket.getaddrinfo(@iclaemail[/@(.*)/, 1].untaint, 'smtp')

  if ASF::Person.find_by_email(@iclaemail)
    _error "ICLA already on file for #{@iclaemail}"
  end
rescue
  _error 'Invalid domain name in email address'
  _focus :iclaemail
end

# validate vote link
if @votelink and not @votelink.empty?

  # attempt to fetch the page
  if @votelink =~ /^https?:/i
    uri = URI.parse(@votelink)
    http = Net::HTTP.new(uri.host.untaint, uri.port)
    if uri.scheme == 'https'
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE 
    end
    request = Net::HTTP::Get.new(uri.request_uri.untaint)
    response = http.request(request)
    unless response.code.to_i < 400
      _error "HTTP status #{response.code} for #{@votelink}"
      _focus :votelink
    end
  else
    _error 'Only http(s) links are accepted for vote links'
    _focus :votelink
  end

end

# add user and pmc emails to the response
_userEmail "#{user.public_name} <#{user.mail.first}>" if user
_pmcEmail "private@#{pmc.mail_list}.apache.org" if pmc

# generate an invitation token
token = Digest::MD5.hexdigest(@iclaemail)[0..15]
path = Pathname.new(env['REQUEST_URI']) + "../../form?token=#{token}"
scheme = env['rack.url_scheme'] || 'https'
link = "#{scheme}://#{env['HTTP_HOST']}#{path}"

# add token and invitation to the response
_token token
_invitation %{Dear #{@iclaname},

#{prototype_contributor if @votelink.empty?}
#{prototype_committer if not @votelink.empty?}
#{prototype_pmc if @noticelink}
Click on this link to accept:
#{link}

Regards,
#{user.public_name if user}
On behalf of the #{pmc.name} project
}
