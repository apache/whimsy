# update /etc/ldap.conf. Usage:
#
#   TEMP HACK for use with github actions to get round gem path issue under sudo
#
#   sudo ruby /srv/whimsy/lib/whimsy/asf/ldap_setup.rb
#

HOSTS = %w(
  ldaps://ldap-us-ro.apache.org:636
  ldaps://ldap-eu-ro.apache.org:636
)

ETCLDAP = case
  when Dir.exist?('/etc/openldap') then '/etc/openldap'
  when Dir.exist?('/usr/local/etc/openldap') then '/user/local//etc/openldap'
  else '/etc/ldap'
end

def configure
  cert = Dir["#{ETCLDAP}/asf*-ldap-client.pem"].first

  # verify/obtain/write the cert
  unless cert
    cert = "#{ETCLDAP}/asf-ldap-client.pem"
    File.write cert, self.extract_cert
  end

  # read the current configuration file
  ldap_conf = "#{ETCLDAP}/ldap.conf"
  content = File.read(ldap_conf)

  # ensure that the right cert is used
  unless content =~ /asf.*-ldap-client\.pem/
    content.gsub!(/^TLS_CACERT/i, '# TLS_CACERT')
    content += "TLS_CACERT #{ETCLDAP}/asf-ldap-client.pem\n"
  end

  # provide the URIs of the ldap HOSTS
  content.gsub!(/^URI/, '# URI')
  content += "uri \n" unless content =~ /^uri /
  content[/uri (.*)\n/, 1] = HOSTS.join(' ')

  # verify/set the base
  unless content.include? 'base dc=apache'
    content.gsub!(/^BASE/i, '# BASE')
    content += "base dc=apache,dc=org\n"
  end

  # ensure TLS_REQCERT is allow (Mac OS/X only)
  if ETCLDAP.include? 'openldap' and not content.include? 'REQCERT allow'
    content.gsub!(/^TLS_REQCERT/i, '# TLS_REQCERT')
    content += "TLS_REQCERT allow\n"
  end

  # write the configuration if there were any changes
  File.write(ldap_conf, content) unless content == File.read(ldap_conf)
end

if __FILE__ == $0
  configure
end
