Overview
==================

Whimsy hosts static content, repository checkouts/clones, CGI scripts, Rack
applications, tools, and cron jobs.

Every committer on the Whimsy PMC can both deploy changes and new
applications to https://whimsy.apache.org/.

Details by content type:

 * **Static content**  Changes pushed to GitHub master will be
   automatically deployed every 30 minutes.  Note that this includes the
   contents of scripts and applications too.
  
 * **Repository checkouts/clones**  An copy of a number of repositories
   are updated every 10 minutes via a cron job.  This is controlled
   by [repository.yml](repository.yml).  The whimsy vm is also subscribed
   to board@ and scans those emails for commit messages and will update
   the copy of `foundation/board` when commits happen.
  
 * **CGI scripts** any dependencies listed in a `Gemfile` will
   automatically be installed.  A simple CGI:

    https://github.com/apache/whimsy/blob/master/www/test.cgi
    https://whimsy.apache.org/test.cgi

   Many CGI scripts will require user authentication.  This is done by adding
   a single line to the deployment data identifying the location of the
   script:

    https://github.com/apache/infrastructure-puppet/blob/deployment/data/nodes/whimsy-vm2.apache.org.yaml#L93

   Note that the LDAP module does not currently handle boolean conditions
   (example: members or officers).  The way to handle this is to do
   authentication in two passes.  The first pass will be done by the Apache
   web server, and verify that the user is a part of the most inclusive group
   (typically: committers).  The CGI scripts that need to do more will need to
   perform additional checks, and output a "Status: 401 Unauthorized" as the
   first line of their output if access to this tool is not permitted for the
   user.

 * **Rack applications** run under
   [Phusion Passenger](https://www.phusionpassenger.com/) under Apache httpd.
   Again, `Gemfile`s are used to specify dependencies.  In addition to simply
   checking the application, one line per passenger application needs to be
   added to the deployment data:

    https://github.com/apache/infrastructure-puppet/blob/deployment/data/nodes/whimsy-vm2.apache.org.yaml#L86

   A simple rack application (two empty directories, and a one line file):

    https://github.com/apache/whimsy/tree/master/www/racktest
    https://whimsy.apache.org/racktest

   Authentication requirements will also need to be two phase, like with CGI
   above; but more common conditions can be handled at the "Rack" level
   instead of at the application level making use of Rack middleware such as:

    https://github.com/apache/whimsy/blob/master/lib/whimsy/asf/rack.rb#L57
    
 * **Cron jobs** are managed by puppet.  See [deployment](DEPLOYMENT.md) for more
   information.

Further Reading
===============

 * [Development](./DEVELOPMENT.md)
 * [Deployment](./DEPLOYMENT.md)
 * [Monitoring](./www/status/README.md)
 * [Todos](TODOS.md).
