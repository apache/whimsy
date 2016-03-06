Deployment
==========

The contents of this repository are deployed to the following VM:
https://whimsy.apache.org/.

The new VM is based on Ubuntu 14.04 (the current Whimsy is based on Ubuntu
12.04), and is more completely managed by Puppet.  The puppet definition is
contained in the following files:

 * https://github.com/apache/infrastructure-puppet/blob/deployment/data/nodes/whimsy-vm2.apache.org.yaml

 * https://github.com/apache/infrastructure-puppet/blob/deployment/modules/whimsy_server/manifests/init.pp

 * https://github.com/apache/infrastructure-puppet/blob/deployment/modules/whimsy_server/manifests/cronjobs.pp

 * https://github.com/apache/infrastructure-puppet/blob/deployment/modules/whimsy_server/manifests/procmail.pp

Instructions:

 * https://github.com/rubys/puppet-kitchen#readme

 * https://github.com/apache/infrastructure-puppet/blob/deployment/modules/vhosts_whimsy/README.md

Workflow:

 * https://cwiki.apache.org/confluence/display/INFRA/Git+workflow+for+infrastructure-puppet+repo
 
Manual Steps
------------

The following additional steps are required to get the Whimsy VM up and running:

 * Configuring `/whimsysvn/.subversion/config` and `/whimsysvn/.subversion/servers` to store auth-creds.

 * Add the following cron job to apmail@hermes:
     * `16 * * * * ezmlm-list /home/apmail/lists/apache.org/board/ . | ssh whimsy-vm2.apache.org 'cat > /srv/subscriptions/board'`

 * Add the following mail subscriptions:
    * Subscribe `svnupdate@whimsy-vm2.apache.org` to `board@apache.org`.
      Alternately, add it to the `board-cvs` alias.
    * Subscribe `svnupdate@whimsy-vm2.apache.org` to 
      `committers-cvs@apache.org`.
    * Subscribe `board@whimsy-vm2.apache.org` to `board@apache.org`.
    * Subscribe `members@whimsy-vm2.apache.org` to `members@apache.org`.
    * Add `secretary@whimsy-vm2.apache.org` to the `secretary@apache.org`
      alias.

The following additional steps are required for now, but will hopefully go
away once the transition away from the secretary workbench is complete:

 * Configuring `/var/www/.subversion/config` and
   `/var/www/.subversion/servers` to store auth-creds and to use the
   `whimsysvn` user.

 * Using the `www-data` user, check out the following repositories:
   * `svn co https://svn.apache.org/repos/private/foundation /srv/secretary/workbench/foundation`
   * `svn co https://svn.apache.org/repos/private/documents /srv/secretary/workbench/documents`
   * `svn co https://svn.apache.org/repos/infra/infrastructure/trunk/subreq /srv/secretary/workbench/subreq`

 * Copy `www/secretary/workbench/secmail.rb` to
   `/srv/secretary/workbench/secmail.rb`
