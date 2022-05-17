#!/usr/bin/env ruby

# Determines if a host name is controlled by the ASF

# TODO: derive from the list at:
# https://raw.githubusercontent.com/apache/privacy-website/main/policies/asf-domains.md

module ASFDOMAIN
  ASF_DOMAINS = %w{
    any23.com
    any23.org
    apache-extras.org
    apache.org
    apachecon.com
    apachecon.org
    apacheextras.org
    apachextras.org
    cloudstack.com
    cloudstack.org
    codehaus.org
    couchapp.com
    couchapp.org
    couchhack.org
    deltaspike.org
    feathercast.org
    freemarker.org
    gremlint.com
    groovy-lang.org
    ignite.run
    jclouds.com
    jclouds.net
    jclouds.org
    jspwiki.org
    libcloud.com
    libcloud.net
    libcloud.org
    modssl.com
    modssl.net
    myfaces.org
    netbeans.org
    ofbiz.org
    openoffice.org
    openwhisk.com
    openwhisk.net
    openwhisk.org
    projectgeode.org
    qi4j.org
    spamassassin.org
    subversion.com
    subversion.net
    subversion.org
    tinkerpop.com
  }
  # Check if a host name is known to be under ASF control
  def self.asfhost?(host)
    return true if ASF_DOMAINS.include? host
    # This assumes all ASF domains are of the form a.b
    return host =~ %r{\.(\w+\.\w+)\z} && ASF_DOMAINS.include?($1)
  end
  # check if URL is known to be under ASF control
  # extracts hostname and calls asfhost?
  def self.asfurl?(url)
    if url =~ %r{\Ahttps?://(.+?)(/|\z)}i
      return asfhost?($1)
    else
      return true # a relative link
    end
  end
  # Return external host name or nil
  # extracts hostname and calls asfhost?
  def self.to_ext_host(url)
    if url =~ %r{\Ahttps?://(.+?)(/|\z)}i
      return $1 unless asfhost?($1)
    end
    return nil
  end
end

if __FILE__ == $0
  ARGV.each do |arg|
    p [arg, ASFDOMAIN.asfhost?(arg), ASFDOMAIN.asfurl?(arg)]
  end
end
