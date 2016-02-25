Development Status
==================

Applications consist of static data, CGI scripts, Rack applications, and 
cron jobs.

Every committer on the Whimsy PMC can both
deploy changes and new applications.  A new VM has been provisioned for this
purpose: https://whimsy-test.apache.org/.

Current status:

 * **Static content**  Changes pushed to GitHub master will be
   automatically deployed every 30 minutes.  Note that this includes the
   contents of scripts and applications too.
  
 * **CGI scripts** any dependencies listed in a `Gemfile` will
   automatically be installed.  A simple CGI:

    https://github.com/apache/whimsy/blob/master/www/test.cgi
    https://whimsy-test.apache.org/test.cgi

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

 * **Rack applications** run under Passenger under Apache httpd.
   Again, `Gemfile`s are used to specify dependencies.  In addition to simply
   checking the application, one line per passenger application needs to be added
   to the deployment data:

    https://github.com/apache/infrastructure-puppet/blob/deployment/data/nodes/whimsy-vm2.apache.org.yaml#L86

   A simple rack application (two empty directories, and a one line file):

    https://github.com/apache/whimsy/tree/master/www/racktest
    https://whimsy-test.apache.org/racktest

   Authentication requirements will also need to be two phase, like with CGI
   above; but more common conditions can be handled at the "Rack" level
   instead of at the application level making use of Rack middleware such as:

    https://github.com/apache/whimsy/blob/master/lib/whimsy/asf/rack.rb#L57
    
 * **Cron jobs** are managed by puppet.  See [deployment](DEPLOYMENT.md) for more
   information.


Further Reading
===============

The [board agenda](https://github.com/rubys/whimsy-agenda#readme) application
is an eample of a complete tool that makes extensive use of the library
factoring, has a suite of test cases, and client componentization (using
ReactJS), and provides instructions for setting up both a Docker component and
a Vagrant VM.

If you would like to understand how the view code works, you can get started
by looking at a few of the
[Wunderbar demos](https://github.com/rubys/wunderbar/tree/master/demo)
and [README](https://github.com/rubys/wunderbar/blob/master/README.md).
