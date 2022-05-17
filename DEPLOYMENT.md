Deploying Production Whimsy.apache.org
==========

The production `whimsy.apache.org` server is managed by [Puppet](puppetnode), and
is automatically updated whenever commits are made to the master branch
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
- Various other config-like settings are in [CONFIGURE.md](./CONFIGURE.md)

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

The Whimsy VM runs Ubuntu 20.04 and is fully managed by Puppet using 
the normal methods Apache infra uses for managing servers.  Note however 
that management of Whimsy code and tools is a PMC responsibility.  

<a name="puppetnode"></a>
The **puppet definition** is contained in the following files (these are private files and need a login):

 * https://github.com/apache/infrastructure-p6/blob/production/data/nodes/whimsy-vm6.apache.org.yaml (Includes modules, software, vhosts, ldap realms, and httpd.conf)

 * https://github.com/apache/infrastructure-p6/tree/production/modules/vhosts_whimsy/lib/puppet/functions (macro functions used above)

 * https://github.com/apache/infrastructure-p6/blob/production/modules/whimsy_server/manifests/init.pp (Defines various tools and directories used in some tools)
 
 * https://github.com/apache/infrastructure-p6/blob/production/modules/whimsy_server/manifests/cronjobs.pp (Cronjobs control when /public/*.json is built and code and mail updates)

 * https://github.com/apache/infrastructure-p6/blob/production/modules/whimsy_server/manifests/procmail.pp

Before pushing any changes here, understand the Apache Infra puppet workflow and test:

 * https://cwiki.apache.org/confluence/display/INFRA/Git+workflow+for+infrastructure-puppet+repo
   To understand the high-level workflow for puppet changes.
   
 * https://github.com/apache/infrastructure-puppet-kitchen#readme
   * addition to [Make modules useable](https://github.com/apache/infrastructure-puppet-kitchen#make-modules-useable) step:
 
            rm -rf zmanda_asf
            mkdir -p zmanda_asf/manifests
            echo "class zmanda_asf::client (){}" > zmanda_asf/manifests/client.pp

 * https://github.com/apache/infrastructure-p6/blob/production/modules/vhosts_whimsy/README.md
   This details the changes to default puppet we use for Whimsy.

Manual Steps
------------

The following additional steps are required to get a new Whimsy VM up 
and running - these are only needed for a new deployment.

 * Ensure that the IP address is static, and has been added to the list of allowed mail relays

 * Run the following command to create an SSL cert (see [tutorial](https://www.digitalocean.com/community/tutorials/how-to-secure-apache-with-let-s-encrypt-on-ubuntu-18-04) for details):
     * `/x1/srv/git/letsencrypt/letsencrypt-auto --apache -d whimsy.apache.org -d whimsy6.apache.org -d whimsy-vm6.apache.org -d whimsy-test.apache.org`

 * The SVN settings should now be set up in whimsy-vm5 and later (Puppet 6)

 * check that board-agenda-websocket.service is running:
   * `sudo systemctl status board-agenda-websocket.service` - this should show the service is running and has been up for some while
   * `curl localhost:34234` - should produce 'curl: (52) Empty reply from server' or similar
   * if curl replies with something else, check that the service is still running (and has not just been restarted)
   * if the syslog contains a message of the form: 
     'Sep 24 13:09:07 whimsy-vm6 ruby[3435205]:   what():  Encryption not available on this event-machine'
     then it will be necessary to re-install the gem eventmachine
     If the service still does not start, try stopping and starting it:
     `sudo systemctl stop/start board-agenda-websocket.service`

 * Update the following cron scripts under https://svn.apache.org/repos/infra/infrastructure/apmail/trunk/bin:
     * listmodsubs.sh - add the new host
     * whimsy_qmail_ids.sh - add the new host
     * make sure that the host is added to the known_hosts file on hermes (e.g. rsync whimsyN.apache.org: and agree to the prompt if the hash is correct)
     * the old hosts should be removed sometime after switchover. This approach requires two edits to the files
     but ensures that the rsync has been tested for the new host and allows the new host to be better tested

 * Add the following mail subscriptions (see apmail/trunk/bin/whimsy_subscribe.sh):
    * Subscribe `board@whimsy-vm6.apache.org` to `board@apache.org`.
    * Subscribe `members@whimsy-vm6.apache.org` to `members@apache.org`.
    * Subscribe `www-data@whimsy-vm6.apache.org` to `private-allow@whimsical.apache.org`. (Cron daemon)
    * Subscribe `root@whimsy-vm6.apache.org` to `private-allow@whimsical.apache.org`. (Cron daemon)
    * Add `secretary@whimsy-vm6.apache.org` to the `secretary@apache.org` alias.

 * Verify that email can be sent to non-apache.org email addresses.
   * Run [testmail.rb](tools/testmail.rb)

 * check that mail is being delivered to the /srv/mail directory tree

 * check that mail subscriptions are being updated under /srv/subscriptions

 * if `pip3 show img2pdf` doesn't show version 0.3.1 or later:
   * Run `pip3 install --upgrade img2pdf`

 * Ensure that gitpubsub is working. Check that updates to whimsy git are pulled within 5 minutes or less

 * Synchronising data: Whimsy keeps some data locally on the server. This needs to be copied across prior to switchover.
 Using the `www-data` user, copy over the following directories from
   the previous whimsy-vm server:
   * `/srv/agenda`
   * `/srv/icla`
   * `/srv/gpg` - this contains the public key ring used to check ICLA signatures
   * Note that the /srv/mail/* directories will in general be different between hosts
     This is because the final delivery routes will vary.
     However, rather than try and merge the files, it is simpler to do a full copy of `/srv/mail`

Mail server configuration
-------------------------
The mail server is unlikely to change, but if it does, rsync auth will need to be set up.
  * generate an SSH keypair for the apmail login:
    * `sudo -Hiu apmail`
    * `ssh-keygen -t ecdsa -b 521`
  * copy the public key from `.ssh/id_ecdsa.pub` to the Puppet file `data/nodes/whimsy-vm6.apache.org.yaml` under the `whimsy_server::procmail::apmail_keycontent` key.
