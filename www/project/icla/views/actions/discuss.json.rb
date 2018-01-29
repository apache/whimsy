require 'socket'
require 'net/http'
require 'pathname'

# find pmc and user information
# all ppmcs are also pmcs but not all pmcs are ppmcs

pmc = ASF::Committee.find(@pmc)
ppmc = ASF::Podling.find(@pmc)
pmc_type = if ppmc and ppmc.status == 'current' then 'PPMC' else 'PMC' end

user = ASF::Person.find(env.user)


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

# verify that the link refers to lists.apache.org message on the project list
  if not @votelink=~ /.*lists\.apache\.org.*/
    _error "Please link to a message via lists.apache.org"
  end
  if not @votelink=~ /.*#{pmc.mail_list}(\.incubator)?\.apache\.org.*/
    _error "Please link to the [RESULT][VOTE] message sent to the private list."
  end

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

# validate notice link
if @noticelink and not @noticelink.empty?

  # verify that the link refers to lists.apache.org message on the proper list
  if not @noticelink=~ /.*lists\.apache\.org.*/
    _error "Please link to a message via lists.apache.org"
  end
  if pmc_type == 'PMC' and not @noticelink=~ /.*board@apache\.org.*/
    _error "Please link to the NOTICE message sent to the board list."
  end
  if pmc_type == 'PPMC' and not @noticelink=~ /.*private@incubator\.apache\.org.*/
    _error "Please link to the NOTICE message sent to the incubator private list."
  end

  # attempt to fetch the page
  if @noticelink =~ /^https?:/i
    uri = URI.parse(@noticelink)
    http = Net::HTTP.new(uri.host.untaint, uri.port)
    if uri.scheme == 'https'
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    end
    request = Net::HTTP::Get.new(uri.request_uri.untaint)
    response = http.request(request)
    unless response.code.to_i < 400
      _error "HTTP status #{response.code} for #{@noticelink}"
      _focus :noticelink
    end
    else
    _error 'Only http(s) links are accepted for notice links'
    _focus :noticelink
  end

end

# add user and pmc emails to the response
_userEmail "#{user.public_name} <#{user.mail.first}>" if user
_pmcEmail "private@#{pmc.mail_list}.apache.org" if pmc

# generate an invitation token
date = Date.new.inspect
token = pmc.name + date + Digest::MD5.hexdigest(@iclaemail)[0..5]
path = Pathname.new(env['REQUEST_URI']) + "../../form?token=#{token}"
scheme = env['rack.url_scheme'] || 'https'
link = "#{scheme}://#{env['HTTP_HOST']}#{path}"

# add token and invitation to the response
_token token
_message %{Dear #{@iclaname},

Click on this link to accept:
#{link}

Regards,
#{user.public_name if user}
On behalf of the #{pmc.name} project
}
