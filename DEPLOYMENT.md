Deployment
==========

The contents of this repository are automatically deployed to the https://whimsy.apache.org/ VM every 30 minutes.

This VM runs Ubuntu 14.04 and is managed by Puppet.  The puppet definition is
contained in the following files:<a name="puppetnode"></a>

 * https://github.com/apache/infrastructure-puppet/blob/deployment/data/nodes/whimsy-vm3.apache.org.yaml

 * https://github.com/apache/infrastructure-puppet/blob/deployment/modules/whimsy_server/manifests/init.pp

 * https://github.com/apache/infrastructure-puppet/blob/deployment/modules/whimsy_server/manifests/cronjobs.pp

 * https://github.com/apache/infrastructure-puppet/blob/deployment/modules/whimsy_server/manifests/procmail.pp

Instructions for local testing of deployment changes:

 * https://github.com/apache/infrastructure-puppet-kitchen#readme
   * addition to [Make modules useable](https://github.com/apache/infrastructure-puppet-kitchen#make-modules-useable) step:
 
            rm -rf zmanda_asf
            mkdir -p zmanda_asf/manifests
            echo "class zmanda_asf::client (){}" > zmanda_asf/manifests/client.pp

 * https://github.com/apache/infrastructure-puppet/blob/deployment/modules/vhosts_whimsy/README.md

Workflow:

 * https://cwiki.apache.org/confluence/display/INFRA/Git+workflow+for+infrastructure-puppet+repo
 
Manual Steps
------------

The following additional steps are required to get the Whimsy VM up and running:

 * Run the following command to create an SSL cert (see [tutorial](https://www.digitalocean.com/community/tutorials/how-to-secure-apache-with-let-s-encrypt-on-ubuntu-14-04) for details):
     * `/x1/srv/git/letsencrypt/letsencrypt-auto --apache -d whimsy.apache.org -d whimsy3.apache.org -d whimsy-vm3.apache.org -d whimsy-test.apache.org`

 * Configure `~/whimsysvn/.subversion/config` and `~/whimsysvn/.subversion/servers` to store auth-creds.

 * Add the following cron job to apmail@hermes:
     * `11  4,10,16,22 * * * for list in /home/apmail/lists/incubator.apache.org/*; do echo; echo $list/mod; ezmlm-list $list mod; done | ssh whimsy-vm3.apache.org 'cat > /srv/subscriptions/incubator-mods'`
     * `16 * * * * ezmlm-list /home/apmail/lists/apache.org/board/ . | ssh whimsy-vm3.apache.org 'cat > /srv/subscriptions/board'`
     * `46 * * * * ezmlm-list /home/apmail/lists/apache.org/members/ . | ssh whimsy-vm3.apache.org 'cat > /srv/subscriptions/members'`

 * Add the following mail subscriptions:
    * Subscribe `svnupdate@whimsy-vm3.apache.org` to `board@apache.org`.
      Alternately, add it to the `board-cvs` alias.
    * Subscribe `svnupdate@whimsy-vm3.apache.org` to 
      `committers-cvs@apache.org`.
    * Subscribe `board@whimsy-vm3.apache.org` to `board@apache.org`.
    * Subscribe `members@whimsy-vm3.apache.org` to `members@apache.org`.
    * Add `secretary@whimsy-vm3.apache.org` to the `secretary@apache.org`
      alias.

 * Verify that email can be sent to non-apache.org email addresses
   * Run [testmail.rb](tools/testmail.rb)

The following additional steps are required for now, but will hopefully go
away once the transition away from the secretary workbench is complete:

 * Configure `/var/www/.subversion/config` and
   `/var/www/.subversion/servers` to store auth-creds and to use the
   `whimsysvn` user.

 * Using the `www-data` user, check out the following repositories:
   * `svn co https://svn.apache.org/repos/private/foundation /srv/secretary/workbench/foundation`
   * `svn co https://svn.apache.org/repos/private/documents /srv/secretary/workbench/documents`
   * `svn co https://svn.apache.org/repos/infra/infrastructure/trunk/subreq /srv/secretary/workbench/subreq`
   * `svn co https://svn.apache.org/repos/infra/infrastructure/trunk/tlpreq/input /srv/secretary/tlpreq`

 * Copy `www/secretary/workbench/secmail.rb` to
   `/srv/secretary/workbench/secmail.rb`
