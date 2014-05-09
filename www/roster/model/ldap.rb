class ASF::RosterLDAP
  def self.get
    dump = File.expand_path('../ldap.dump', __FILE__.untaint).untaint
    if File.exist? dump
      ldap = eval File.read(dump).untaint
    else
      ldap_connection = ASF.init_ldap
      ldap = ldap_connection.search2 'dc=apache,dc=org', 
        LDAP::LDAP_SCOPE_SUBTREE, 'objectclass=*'
    end

    services = {}
    pmcs = {}
    groups = {}
    committers = {}

    ldap.each do |entry|
      next if entry['objectClass'].include? 'organizationalUnit'
      cn = entry['cn'].first
      dn = entry['dn'].first

      if entry['objectClass'].include? 'groupOfNames'
        entry['memberUid'] = entry.delete('member').
          map {|dn| dn[/uid=(.*?),/,1]}
        if dn == "cn=#{cn},ou=pmc,ou=committees,ou=groups,dc=apache,dc=org"
          pmcs[cn] = flatten(entry)
        elsif dn == "cn=#{cn},ou=groups,ou=ianh,ou=sandbox,dc=apache,dc=org"
          # ignore sandbox
        elsif dn == "cn=#{cn},ou=groups,ou=sandbox,dc=apache,dc=org"
          # ignore sandbox
        else
          services[cn] = flatten(entry)
        end
      elsif entry['objectClass'].include? 'posixGroup'
        if dn == "cn=#{cn},ou=people,ou=groups,dc=apache,dc=org"
          # ignore posixGroup entries for users
        elsif dn == "cn=#{cn},ou=sudoers,ou=groups,ou=services,dc=apache,dc=org"
          # ignore sudoers
        else
          groups[cn] = flatten(entry)
        end
      else
        if entry['objectClass'].include? 'asf-committer'
          committers[entry['uid'].first] = flatten(entry)
        elsif dn == "cn=#{cn},ou=users,ou=services,dc=apache,dc=org"
          # ignore role accounts
        elsif dn == "cn=#{cn},ou=sandbox,dc=apache,dc=org"
          # ignore sandbox accounts
        elsif dn == "cn=#{cn},dc=apache,dc=org" and cn.include? '-ppolicy'
          # ignore sandbox accounts
        else
          puts
          p entry
        end
      end
    end

    services.values.each {|ldap| ldap['objectClass'] -= ['groupOfNames', 'top']}
    pmcs.values.each {|ldap| ldap['objectClass'] -= ['groupOfNames', 'top']}
    committers.values.each {|ldap| ldap['objectClass'] -= ["person", "top",
      "posixAccount", "organizationalPerson", "inetOrgPerson", "asf-committer"]}

    services.delete('apldap')

    groups.values.each do |ldap| 
      ldap['objectClass'] -= ['posixGroup', 'top']
      ldap['memberUid'] ||= []
    end

    {services: services, pmcs: pmcs, committers: committers, groups: groups}
  end

  private
    def self.flatten(entry)
      entry.each do |key, value|
        entry[key] = value.first if value.length == 1 and 
          not %w(objectClass memberUid mail asf-altEmail asf-pgpKeyFingerprint).
            include? key
      end

      entry.delete('userPassword') if entry['userPassword'] == '{crypt}*'
      entry.delete('dn')

      entry['cn'].force_encoding('utf-8') if entry['cn']
      entry['sn'].force_encoding('utf-8') if entry['sn']

      entry
    end
end
