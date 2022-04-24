require 'socket'
require 'net/http'
require 'pathname'

# Validates and prepares invitations

# Called from invite.js.rb POST
# expects the following variables to be set:
# @pmc
# @iclaemail
# @iclaname
# @votelink
# @noticelink

# returns the following keys:
#  error
#  focus
#  token
#  pmcEmail
#  userEmail
#  invitation

# find pmc and user information
# all ppmcs are also pmcs but not all pmcs are ppmcs

pmc = ASF::Committee.find(@pmc)
ppmc = ASF::Podling.find(@pmc)
pmc_type = if ppmc and ppmc.status == 'current' then 'PPMC' else 'PMC' end

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

You can read more about what the expectations are for committers here:
http://www.apache.org/dev/committers.html#committer-responsibilities

These privileges are offered on the understanding that you'll use them
reasonably and with common sense. We like to work on trust rather than
unnecessary constraints.

Being a committer enables you to more easily make changes without needing to
go through the patch submission process.

Being a committer does not require you to participate any more than you already
do, but it does tend to make one even more committed ;-) You will probably find
that you spend more time here.

"

prototype_pmc =
"You are also invited to become a member of the #{pmc.name} PMC.
Being a PMC member enables you to help guide the direction of the project.
You can read more about what the expectations are for PMC members here:
http://www.apache.org/dev/pmc.html#audience

"

prototype_ppmc =
"You are also invited to become a member of the #{pmc.name} PPMC.
Being a PPMC member enables you to help guide the direction of the project.
You can read more about what the expectations are for PPMC members here:
https://incubator.apache.org/guides/ppmc.html

"

prototype_committer_or_pmc =
"Of course, you can decline and instead remain as a contributor, participating
as you do now.

This personal invitation is a chance for you to accept or decline in private.
Either way, please let us know in reply to the private@ address only.
"
# validate email address
if ASF::Person.find_by_email(@iclaemail)
  _error "ICLA already on file for #{@iclaemail}"
  _focus :iclaemail
  return # no point in continuing
end

begin
  Socket.getaddrinfo(@iclaemail[/@(.*)/, 1].untaint, 'smtp')
rescue
  _error 'Invalid domain name in email address'
  _focus :iclaemail
  return # no point in continuing
end

# validate vote link
if @votelink and not @votelink.empty?

# verify that the link refers to lists.apache.org message on the project list
  if not @votelink=~ /.*lists\.apache\.org.*/
    _error "Please link to a message via lists.apache.org"
    return # no point in continuing
  end
  if not @votelink=~ /.*#{pmc.mail_list}(\.incubator)?\.apache\.org.*/
    _error "Please link to the [RESULT][VOTE] message sent to the private list."
    return # no point in continuing
  end

  # attempt to fetch the page
  if @votelink =~ /^https?:/i
    uri = URI.parse(@votelink)
    http = Net::HTTP.new(uri.host.untaint, uri.port)
    if uri.scheme == 'https'
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    end
    request = Net::HTTP::Head.new(uri.request_uri.untaint)
    response = http.request(request)
    unless response.code.to_i < 400
      _error "HTTP status #{response.code} for #{@votelink}"
      _focus :votelink
      return # no point in continuing
    end
  else
    _error 'Only http(s) links are accepted for vote links'
    _focus :votelink
    return # no point in continuing
  end

end

# validate notice link
if @noticelink and not @noticelink.empty?

  # verify that the link refers to lists.apache.org message on the proper list
  if not @noticelink=~ /.*lists\.apache\.org.*/
    _error "Please link to a message via lists.apache.org"
    return # no point in continuing
  end
  if pmc_type == 'PMC' and not @noticelink=~ /.*board@apache\.org.*/
    _error "Please link to the NOTICE message sent to the board list."
    return # no point in continuing
  end
  if pmc_type == 'PPMC' and not @noticelink=~ /.*private@incubator\.apache\.org.*/
    _error "Please link to the NOTICE message sent to the incubator private list."
    return # no point in continuing
  end

  # attempt to fetch the page
  if @noticelink =~ /^https?:/i
    uri = URI.parse(@noticelink)
    http = Net::HTTP.new(uri.host.untaint, uri.port)
    if uri.scheme == 'https'
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    end
    request = Net::HTTP::Head.new(uri.request_uri.untaint)
    response = http.request(request)
    unless response.code.to_i < 400
      _error "HTTP status #{response.code} for #{@noticelink}"
      _focus :noticelink
      return # no point in continuing
    end
  else
    _error 'Only http(s) links are accepted for notice links'
    _focus :noticelink
    return # no point in continuing
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

#{prototype_contributor if @votelink.empty?}\
#{prototype_committer if not @votelink.empty?}\
#{prototype_pmc if not @noticelink.empty? and (pmc_type == 'PMC')}\
#{prototype_ppmc if not @noticelink.empty? and (pmc_type == 'PPMC')}\
#{prototype_committer_or_pmc if not @votelink.empty?}
Click on this link to accept:
#{link}

Regards,
#{user.public_name if user}
On behalf of the #{pmc.display_name} project
}
