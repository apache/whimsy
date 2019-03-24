#
# Update PGP keys attribute for a committer
#

person = ASF::Person.find(@userid)

# report the previous value in the response
_previous asf_personalURL: person.attrs['asf-personalURL']

if @urls  # must agree with urls.js.rb

  # report the new values
  _replacement asf_personalURL: @urls

  @urls.each do |url|
#    next
    begin
      uri = URI.parse(url)
    rescue
      _error "Cannot parse URL: #{url}"
      return
    end
    unless uri.scheme =~ /^https?$/ && uri.host.length > 5
      _error "Invalid http(s) URL: #{url}"
      return
    end
  end

  # update LDAP
  unless @dryrun
    _ldap.update do
      person.modify 'asf-personalURL', @urls
    end
  end
end

# return updated committer info
_committer Committer.serialize(@userid, env)
