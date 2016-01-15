TODOs
=====

1. Get a handle on how to test LDAP changes locally.  LDAP is installed on
   whimsy-vm2, but not on local puppet-kitchen-vagrant repositories.

2. Define a strategy for maintaining checkout data (mostly SVN) which is
   needed by multiple applications.  For production, that will mean deployment
   on things like credentials for the `whimsysvn` user.  For local testing
   that likely will mean mounting local directories by the VM.

4. Deploy puma (https://forge.puppetlabs.com/deversus/puma), and merge the
   [board agenda](https://github.com/rubys/whimsy-agenda) tool into this
   repository.

5. Implement a fine grained availability and monitoring system
   [Whimsy-35](https://issues.apache.org/jira/browse/WHIMSY-35).
   At the moment, this is a simple ping endpoint.
