person = ASF::Person.find(@name)

_member person.asf_member?

name = {}

if person.icla
  name[:public_name] = person.public_name
  name[:legal_name] = person.icla.legal_name
end

unless person.attrs['cn'].empty?
  name[:ldap] = person.attrs['cn'].first.force_encoding('utf-8')
end

_name name

_mail person.all_mail

_pgp person.pgp_key_fingerprints unless person.pgp_key_fingerprints.empty?

_urls person.urls unless person.urls.empty?

_groups person.groups.map(&:name)

_committees person.committees.map(&:name)
