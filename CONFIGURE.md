# Configuring Whimsy

As a collection of tools that directly access organizational data,
there are a number of places that you will need to configure to
have most of the code work as expected.  Whimsy Ruby code can
run either in a local environment or with a webserver.

## Dependencies

- Compilers & Servers
  - Ruby 2.x.x (Production version: 2.3.)
  - Apache HTTP Web Server 2.x
  - Rack
  - Phusion Passenger
  - Puppet (for our [production](DEPLOYMENT.md) deployment)
- A variety of Ruby gems
  - [Wunderbar](https://github.com/rubys/wunderbar) - HTML Generator and CGI application support
  - [Ruby-ldap](https://github.com/bearded/ruby-ldap) - LDAP for Ruby
  - [nokogiri](https://github.com/sparklemotion/nokogiri) - HTML parser for Ruby
  - Full gem dependencies in `asf.gemspec`

## Local Clients / Development

Whimsy can be run on a client or in a local container for development use.

* **App-wide default settings** are stored in a local YAML formatted
  `~/.whimsy` file, notably including an `svn` pointer to where various
  local repo checkouts live as well as `sendmail` config (if used).
  See also `lib/whimsy/asf/config.rb`

* **LDAP configuration** will be stored in `/etc/(ldap|openldap)/ldap.conf`
  and will point to the production ASF LDAP servers along with associated
  certificate.  See also `lib/whimsy/asf/ldap.rb` and `ASF::LDAP.configure`.
  Settings can be overridden in the `.whimsy` config file.
  Note that HTTP authentication also uses LDAP. To avoid problems with TLS
  certificates, the servers should be the same as for app access.

* **Web server configuration** - much of Whimsy runs within an Apache
  httpd instance, so see the usual `/etc/apache2/httpd.conf` along
  with associated Rack and/or Phusion configurations.

* **Log files and debugging** are typically found in `/var/log/apache2/whimsy_error.log`
  and `/var/log/apache2/error_log`

* **Development setup instructions** are in [DEVELOPMENT.md](DEVELOPMENT.md) and [MACOSX.md](MACOSX.md).

* **whimsy-asf Gem** is a set of the core lib/whimsy/asf model as a normal Gem: [asf.gemspec](asf.gemspec)
  
* **Tool-specific configurations** can be found in config/ directory  

## Production Server Configuration

See [DEPLOYMENT.md](DEPLOYMENT.md) for full details.  We use Puppet to 
provision the production VM with the basic dependencies as well as the 
Whimsy code.  A number of configuration steps ensure the production instance
has access to LDAP, SVN repositories (some read/write), local mail
sending and receiving/subscriptions.

* **Log files** are LDAP secured to Members in: https://whimsy.apache.org/members/log/
