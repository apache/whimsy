Deploying Production Whimsy.apache.org
==========

The production `whimsy.apache.org` server is managed by [Puppet](puppetnode), and 
is automatically udpated whenever commits are made to the master branch
of this repository.  Thus code changes here are reflected in the production
server within a few minutes.  In the event of a major server crash, the 
infra team simply re-deploys the whole VM from Puppet.

**Committers:** please test changes to end-user critical scripts before 
committing to master! 

To deploy a completely _new_ whimsy VM, see [Manual Steps](#manual-steps).

Configuration Locations
----
Application developers may need to know where different things are configured:

- Most **httpd config** is in the [puppet definition whimsy-vm*.apache.org.yaml](#puppetnode)
- **SVN / git** updaters and definitions of checkout directories are in [repository.yml](repository.yml)
- **Cron jobs** are configured by whimsy_server/manifests/cronjobs.pp, which call various Public JSON scripts
- **Public JSON** generation comes from various www/roster/public_*.rb scripts
- **Misc server config** is executed by whimsy_server/manifests/init.pp
- **LDAP** configured in whimsy-vm*.apache.org.yaml

How Production Is Updated
----

- When Puppet updates the whimsy VM, it uses modules/whimsy_server/manifests/init.pp
  to define the 'whimsy-pubsub' service which runs [tools/pubsub.rb](tools/pubsub.rb)
- pubsub.rb watches for any commits from the whimsy git repo at gitbox.apache.org
- When it detects a change, it tells Puppet to update the VM as a whole
- Puppet then updates various svn/git repositories, ensures required tools and setup 
  is done if there are other changes to dependencies, and when needed restarts most 
  services that might need a restart
- Puppet also does a `rake update` to update various gem or ruby settings

Thus, in less than 5 minutes from any git push, the server is running the new code!


Production Configuration
==========

The Whimsy VM runs Ubuntu 16.04 and is fully managed by Puppet using 
the normal methods Apache infra uses for managing servers.  Note however 
that management of Whimsy code and tools is a PMC responsibility.  

<a name="puppetnode"></a>
The **puppet definition** is contained in the following files:

 * https://github.com/apache/infrastructure-puppet/blob/deployment/data/nodes/whimsy-vm4.apache.org.yaml (Includes modules, software, vhosts, ldap realms, and httpd.conf)

 * https://github.com/apache/infrastructure-puppet/blob/deployment/modules/vhosts_whimsy/lib/puppet/parser/functions/preprocess_vhosts.rb (macro functions used above)

 * https://github.com/apache/infrastructure-puppet/blob/deployment/modules/whimsy_server/manifests/init.pp (Defines various tools and directories used in some tools)
 
 * https://github.com/apache/infrastructure-puppet/blob/deployment/modules/whimsy_server/manifests/cronjobs.pp (Cronjobs control when /public/*.json is built and code and mail updates)

 * https://github.com/apache/infrastructure-puppet/blob/deployment/modules/whimsy_server/manifests/procmail.pp

Before pushing any changes here, understand the Apache Infra puppet workflow and test:

 * https://cwiki.apache.org/confluence/display/INFRA/Git+workflow+for+infrastructure-puppet+repo
   To understand the high-level workflow for puppet changes.
   
 * https://github.com/apache/infrastructure-puppet-kitchen#readme
   * addition to [Make modules useable](https://github.com/apache/infrastructure-puppet-kitchen#make-modules-useable) step:
 
            rm -rf zmanda_asf
            mkdir -p zmanda_asf/manifests
            echo "class zmanda_asf::client (){}" > zmanda_asf/manifests/client.pp

 * https://github.com/apache/infrastructure-puppet/blob/deployment/modules/vhosts_whimsy/README.md
   This details the changes to default puppet we use for Whimsy.

Manual Steps
------------

The following additional steps are required to get a new Whimsy VM up 
and running - these are only needed for a new deployment.

 * Run the following command to create an SSL cert (see [tutorial](https://www.digitalocean.com/community/tutorials/how-to-secure-apache-with-let-s-encrypt-on-ubuntu-14-04) for details):
     * `/x1/srv/git/letsencrypt/letsencrypt-auto --apache -d whimsy.apache.org -d whimsy4.apache.org -d whimsy-vm4.apache.org -d whimsy-test.apache.org`

 * Configure `/home/whimsysvn/.subversion/config` and
   `/home/whimsysvn/.subversion/servers` to store auth-creds.

 * Configure `/var/www/.subversion/config` and
   `/var/www/.subversion/servers` to use the `whimsysvn` user and to *not*
   store the auth-creds.

 * Update the following cron scripts under https://svn.apache.org/repos/infra/infrastructure/apmail/trunk/bin:
     * listmodsubs.sh - if necessary, add an rsync to the old Whimsy host
     * whimsy_qmail_ids.sh - add the new host
     
 * Add the following mail subscriptions:
    * Subscribe `svnupdate@whimsy-vm4.apache.org` to `board-commits@apache.org`.
      Alternately, add it to the `board-cvs` alias.
    * Subscribe `svnupdate@whimsy-vm4.apache.org` to 
      `committers-cvs@apache.org`.
    * Subscribe `board@whimsy-vm4.apache.org` to `board@apache.org`.
    * Subscribe `members@whimsy-vm4.apache.org` to `members@apache.org`.
    * Add `secretary@whimsy-vm4.apache.org` to the `secretary@apache.org`
      alias.

 * Update the lists of archivers in www/board|members/subscriptions.cgi

 * Using the `www-data` user, copy over the following directories from
   the previous whimsy-vm* server: `/srv/agenda`, `/srv/mail/board`,
   ``/srv/icla`, /srv/mail/members`, `/srv/mail/secretary`.
 
 * Verify that email can be sent to non-apache.org email addresses
   * Run [testmail.rb](tools/testmail.rb)
