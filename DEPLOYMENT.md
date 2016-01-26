Deployment
==========

The contents of this repository are deployed to the following VM:
https://whimsy-test.apache.org/.

The new VM is based on Ubuntu 14.04 (the current Whimsy is based on Ubuntu
12.04), and is more completely managed by Puppet.  The puppet definition is
contained in the following two files:

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

The following additional steps are required to get a the Whimsy VM up and running:

 * Configuring `/root/.subversion/config` and `/root/.subversion/servers` store auth-creds and to use
   the username `whimsysvn`.

 * Initial checkouts of the various svn sources used by various whimsy tools.  These checkouts are
   to be placed in the `/srv/svn` directory, owned by `root` and often have `--depth=files` specified.
   The [svninfo](toools/svninfo) tool may be used to build a script that can be used to perform
   the checkouts.  Once checked out, the sources will be kept up to date by a cron job.
