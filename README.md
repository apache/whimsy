Apache Whimsy Project Overview
==================

Apache Whimsy is a collection of useful organizational tools used by 
the ASF and Apache committers to access and manipulate data about 
Apache people, projects, and more.  Whimsy is both an Apache PMC, 
this codebase, and the live deployed instance of https://whimsy.apache.org/.

The ASF's Whimsy instance hosts static content, repository checkouts/clones, CGI scripts, Rack
applications, tools, and cron jobs.  Note: features accessing private 
ASF data are restricted to committers, Members, or Officers of the ASF. 

Every committer on the Whimsy PMC can both deploy changes and new
applications to https://whimsy.apache.org/. 

How Tos and Get The Code
===============

Whimsy source code is hosted at:
    https://github.com/apache/whimsy.git
and now also mirrored for Apache committers at:
    https://gitbox.apache.org/repos/asf/whimsy.git

 * [How To Develop Whimsy Code](./DEVELOPMENT.md)
 * [Submit Bugs](https://issues.apache.org/jira/browse/WHIMSY)
 * [Questions? Email The List](https://lists.apache.org/list.html?dev@whimsical.apache.org)
 * [Deployment Instructions](./DEPLOYMENT.md)
 * [Configuration Pointers](./CONFIGURE.md)
 * [Monitoring How To](./www/status/README.md) - [Live Whimsy Status](https://whimsy.apache.org/status/)
 * [How To Setup on Mac OSX](./MACOSX.md)
 * [Dependency Listing](./SOFTWARE.md)
 * [Todos](TODOS.md).

Whimsy Architecture - Live Instance
===================

Whimsy is run in an Apache hosted VM with httpd, Rack, Ruby, and variety of other tools 
that directly interface with various parts of Apache organziational records.

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

    https://github.com/apache/infrastructure-puppet/blob/deployment/data/nodes/whimsy-vm3.apache.org.yaml#L126

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
   added to the puppet file under 'passenger:` as seen in [DEPLOYMENT.md](./DEPLOYMENT.md#puppetnode).

   A sample rack application (two empty directories, and a one line file):

    https://github.com/apache/whimsy/tree/master/www/racktest
    https://whimsy.apache.org/racktest

   Authentication requirements will also need to be two phase, like with CGI
   above; but more common conditions can be handled at the "Rack" level
   instead of at the application level making use of Rack middleware such as:

    https://github.com/apache/whimsy/blob/master/lib/whimsy/asf/rack.rb#L57
    
 * **Cron jobs** are managed by puppet.  See [deployment](DEPLOYMENT.md) for more
   information.
   
 * **Generated JSON data** files are automatically generated into 
   the [`/public`](https://whimsy.apache.org/public/) directory, to 
   cache freqently used data for whimsy and other applications. 
  
 * **Data models** for many Whimsy tools are in `lib/whimsy/asf`, and 
   most **views** for tools are stored in `www`.  Note what Whimsy has 
   a wide variety of sometimes unrelated tools, so not everything 
   here uses the same models.
