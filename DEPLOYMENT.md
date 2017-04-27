Deploying Production Whimsy.apache.org
==========

The contents of this repository are automatically deployed to the production 
https://whimsy.apache.org/ VM every 30 minutes - so be sure to test 
your changes before pushing to master.

Configuration Locations
----
Application developers may need to know where different things are configured:

- Most **httpd config** is in the puppet definition whimsy-vm*.apache.org.yaml (below)
- **SVN / git** updaters are in [repository.yml](repository.yml)
- **Public JSON** generation comes from tools and controlled by whimsy_server/manifests/cronjobs.pp
- **LDAP** configured in whimsy-vm*.apache.org.yaml

Production Configuration
==========

The Whimsy VM runs Ubuntu 14.04 and is fully managed by Puppet using 
the normal methods Apache infra uses for managing servers.  Note however 
that management of Whimsy is a PMC responsibility.  

<a name="puppetnode"></a>
The **puppet definition** is contained in the following files:

 * https://github.com/apache/infrastructure-puppet/blob/deployment/data/nodes/whimsy-vm3.apache.org.yaml (Includes modules, software, vhosts, ldap realms, and httpd.conf)

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

The following additional steps are required to get the Whimsy VM up and running:

 * Run the following command to create an SSL cert (see [tutorial](https://www.digitalocean.com/community/tutorials/how-to-secure-apache-with-let-s-encrypt-on-ubuntu-14-04) for details):
     * `/x1/srv/git/letsencrypt/letsencrypt-auto --apache -d whimsy.apache.org -d whimsy3.apache.org -d whimsy-vm3.apache.org -d whimsy-test.apache.org`

 * Configure `/var/www/.subversion/config` and
   `/var/www/.subversion/servers` to store auth-creds and to use the
   `whimsysvn` user.

 * Add the following cron job to apmail@hermes:
     * `11  4,10,16,22 * * * for list in /home/apmail/lists/incubator.apache.org/*; do echo; echo $list/mod; ezmlm-list $list mod; done | ssh whimsy-vm4.apache.org 'cat > /srv/subscriptions/incubator-mods'`
     * `11  1,7,13,19   *       *       *       for list in /home/apmail/lists/*apache.org/*; do echo; echo $list/mod; ezmlm-list $list mod; done 2>/dev/null | ssh whimsy-vm4.apache.org 'cat > /srv/subscriptions/list-mods'`
     * `11  3,9,15,21   *       *       *       for list in /home/apmail/lists/*apache.org/*; do echo; echo $list/mod; ezmlm-list $list 2>/dev/null; done | ssh whimsy-vm4.apache.org 'cat > /srv/subscriptions/list-subs'`
     * `16 * * * * ezmlm-list /home/apmail/lists/apache.org/board/ . | ssh whimsy-vm4.apache.org 'cat > /srv/subscriptions/board'`
     * `46 * * * * ezmlm-list /home/apmail/lists/apache.org/members/ . | ssh whimsy-vm4.apache.org 'cat > /srv/subscriptions/members'`

 * Add the following mail subscriptions:
    * Subscribe `svnupdate@whimsy-vm3.apache.org` to `board@apache.org`.
      Alternately, add it to the `board-cvs` alias.
    * Subscribe `svnupdate@whimsy-vm3.apache.org` to 
      `committers-cvs@apache.org`.
    * Subscribe `board@whimsy-vm3.apache.org` to `board@apache.org`.
    * Subscribe `members@whimsy-vm3.apache.org` to `members@apache.org`.
    * Add `secretary@whimsy-vm3.apache.org` to the `secretary@apache.org`
      alias.

 * Using the `www-data` user, copy over the following directories from
   the previous whimsy-vm* server: `/srv/agenda`, `/srv/mail/board`,
   `/srv/mail/members`, `/srv/mail/secretary`.
 
 * Verify that email can be sent to non-apache.org email addresses
   * Run [testmail.rb](tools/testmail.rb)

The following additional steps are required for now, but will hopefully go
away once the transition away from the secretary workbench is complete:

 * Using the `www-data` user, check out the following repositories:
   * `svn co https://svn.apache.org/repos/private/foundation /srv/secretary/workbench/foundation`
   * `svn co https://svn.apache.org/repos/private/documents /srv/secretary/workbench/documents`
   * `svn co https://svn.apache.org/repos/infra/infrastructure/trunk/subreq /srv/secretary/workbench/subreq`
   * `svn co https://svn.apache.org/repos/infra/infrastructure/trunk/tlpreq/input /srv/secretary/tlpreq`

 * Copy `www/secretary/workbench/secmail.rb` to
   `/srv/secretary/workbench/secmail.rb`
