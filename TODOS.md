TODOs
=====

This directory has two main subdirectories...

1. Get a handle on how to test LDAP changes locally.  LDAP is installed on
   whimsy-vm2, but not on local puppet-kitchen-vagrant repositories.

2. Define a strategy for maintaining checkout data (mostly SVN) which is
   needed by multiple applications.  For production, that will mean deployment
   on things like credentials for the `whimsysvn` user.  For local testing
   that likely will mean mounting local directories by the VM.

3. Define a strategy for maintaining dependencies.  Whimsy (as a site) hosts
   multiple independent applications, each of which may have different
   requirements.  I'd like to make it so that not every application has to be
   upgraded at the same time when a new version of a dependency comes out.
   This likely will involve the use of bundler
   (https://forge.puppetlabs.com/ploperations/bundler).

4. Deploy puma (https://forge.puppetlabs.com/deversus/puma), and merge the
   [board agenda](https://github.com/rubys/whimsy-agenda) tool into this
   repository.

5. Set up cron jobs.
