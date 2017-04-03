# Configuring Whimsy

As a collection of tools that directly access organizational data, 
there are a number of places that you will need to configure to 
have most of the code work as expected.

## Local Clients / Development

Whimsy can be run on a client or in a local container for development use.

* **App-wide default settings** are stored in a YAML formatted 
  `~/.whimsy` file, notably including an `svn` pointer to where various 
  local repo checkouts live as well as `sendmail` config (if used).  
  See also `lib/whimsy/asf/config.rb`
  
* **LDAP configuration** will be stored in `/etc/(ldap|openldap)/ldap.conf`
  and will point to the production ASF LDAP servers along with associated 
  certificate.  See also `lib/whimsy/asf/ldap.rb` and `ASF::LDAP.configure`. 

* **Web server configuration** - much of Whimsy runs within an Apache 
  httpd instance, so see the usual `/etc/apache2/httpd.conf` along 
  with associated Rack and/or Phusion configurations.
  
* **Log files and debugging** are typically found in `/var/log/apache2/whimsy_error.log` 
  and `/var/log/apache2/error_log`
  
* **Development setup instructions** are in [DEVELOPMENT.md](DEVELOPMENT.md) and [MACOSX.md](DEVELOPMENT.md).

* **whimsy-asf Gem** is a set of the core whimsy model as a normal Gem: [asf.gemspec](asf.gemspec)
  
* **Tool-specific configurations** can be found in config/ directory  

## Production whimsy

See [DEPLOYMENT.md](DEPLOYMENT.md) for full details.  We use Puppet to 
provision the production VM with the basic dependencies as well as the 
Whimsy code.  A number of configuration steps ensure the production instance
has access to LDAP, SVN repositories (some read/write), local mail
sending and receiving/subscriptions.
