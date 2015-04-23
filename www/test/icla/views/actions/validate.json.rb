require 'socket'
require 'net/http'
require 'pathname'

# find pmc and user information
pmc = ASF::Committee.find(@pmc)
user = ASF::Person.find(env.user)

# validate email address
begin
  Socket.getaddrinfo(@iclaemail[/@(.*)/, 1], 'smtp')

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
    http = Net::HTTP.new(uri.host, uri.port)
    if uri.scheme == 'https'
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE 
    end
    request = Net::HTTP::Get.new(uri.request_uri)
    response = http.request(request)
    unless response.code.to_i < 400
      _error "HTTP status #{response.code} for #{@votelink}"
      _focus :votelink
    end
  else
    _error 'Only http(s) links are accepted for vote links'
    _focus :votelink
  end

  # verify that the user submitting the form is on the PMC in question
  unless pmc and pmc.members.include? user
    _error "You must be on the #@pmc PMC to submit a vote link"
    _focus :pmc
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

Based on your contributions, you are invited to submit an ICLA to The Apache
Software Foundation, using the following form. Please see
http://apache.org/licenses for details.

#{link}

Thanks,
#{user.public_name if user}
}
