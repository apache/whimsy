Apache Whimsy Project Overview
==================

Apache Whimsy is a collection of useful organizational tools used by
the ASF and Apache committers to access and manipulate data about
Apache people, projects, and processes.  Whimsy is both an [Apache PMC](https://whimsical.apache.org/),
this codebase, and the live deployed instance of https://whimsy.apache.org/.

The ASF's Whimsy instance hosts static content, repository checkouts/clones, CGI scripts, Rack
applications, Node.js applications, tools, and cron jobs.  Note: features accessing private
ASF data are restricted to committers, Members, or Officers of the ASF.

Every commit pushed to master is deployed within minutes to https://whimsy.apache.org/ using
[GitPubSub](https://www.apache.org/dev/gitpubsub.html).

[![Build Status](https://api.travis-ci.com/apache/whimsy.svg?)](https://app.travis-ci.com/github/apache/whimsy)

How Tos and Get The Code
===============

Whimsy source code is hosted at:
    https://github.com/apache/whimsy.git
and mirrored for Apache committers at:
    https://gitbox.apache.org/repos/asf/whimsy.git

 * [How To Develop Whimsy Code](./DEVELOPMENT.md)
 * [Submit Bugs/Enhancement Requests](https://issues.apache.org/jira/browse/WHIMSY)
 * [Questions? See the Mailing List](https://lists.apache.org/list.html?dev@whimsical.apache.org)
 * **Setting Up For Local Development**
   * Mac OSX - [Run setupmymac](./SETUPMYMAC.md) or [Follow manual steps on OSX](./MACOSX.md)
   * [Linux-y setup steps](./DEVELOPMENT.md)
   * [Use DOCKER to run Whimsy locally](./DOCKER.md)
   * [General FAQs for developing the Whimsy Way](./DEVELOPMENT.md#how-to--faq-question)
   * [Whimsy API Docs](https://whimsy.apache.org/docs/)
 * [Configuration Pointers](./CONFIGURE.md) - various config settings for server or local use
 * [Production Server Deployment Instructions](./DEPLOYMENT.md)
 * [Monitoring How To](./www/status/README.md) - [Live Whimsy Status](https://whimsy.apache.org/status/)
 * [Dependency Listing](./CONFIGURE.md#Dependencies)

How To Get Involved!
===============

Since Whimsy hosts many independent tools that make finding or updating information
at the ASF simpler, there are plenty of places for Apache committers to
get involved.  Bugs or improvement suggestions for the many
[tools available on Whimsy](https://whimsy.apache.org/committers/tools)
or [list of public datafiles](https://whimsy.apache.org/test/dataflow.cgi) are always appreciated,
and please join us on the [public #whimsy channel on Slack](https://the-asf.slack.com/).

If you have an idea for a new Whimsy tool, [email us](mailto:dev@whimsical.apache.org?subject=Tool-Idea)!
The PMC supports a rich server environment, so deploying a new tool is as 
simple as proposing a .cgi with a bit of Ruby code.  We also have deployments 
of Rack and Sinatra apps, and use JavaScript and Wunderbar for most of the 
UI building in many tools. The Whimsy server also supports direct access 
to Apache SVN or git repositories, making consuming data simple.

The Whimsy committers are always looking for new ideas to improve processes 
at Apache, and we can either help you get started or suggest how to 
approach just about any sort of "find this ASF data and streamline that 
process" ideas.

Most documentation is in the code or in the repo, and our dev@whimsical
mailing list is active.  Note that many Whimsy tools access committer- or 
member-private data, so some tools are access restricted.

**Historical note:** The live production whimsy.apache.org server was used for 
the board agenda tool and more before we became the Apache Whimsy top level 
project.  That's why [whimsy.apache.org](https://whimsy.apache.org/) is 
the production server, and mailing lists and a homepage are hosted 
on the [whimsical.apache.org](https://whimsical.apache.org/) domain.

Whimsy Architecture - Live Instance
===================

Whimsy is run in an Apache hosted VM with httpd, Rack, Ruby, and variety of other tools 
that directly interface with various parts of Apache organizational records.

Details for each type of deployed tool or script:

 * **Static content**  Changes pushed to GitHub master will be
   automatically deployed - every commit triggers the puppet agent to 
   do an update, which may take a few minutes.  Note that this includes the
   contents of scripts and applications too.
  
 * **Repository checkouts/clones**  An copy of a number of repositories
   are updated every 10 minutes via a cron job.  This is controlled
   by [repository.yml](repository.yml).  The whimsy VM is also subscribed
   to board@ and scans those emails for commit messages and will update
   the copy of `foundation/board` when commits happen.
  
 * **CGI scripts** any dependencies listed in a `Gemfile` will
   automatically be installed.  A simple CGI:

    https://github.com/apache/whimsy/blob/master/www/test.cgi
    https://whimsy.apache.org/test.cgi

 * **Authentication for CGI Scripts** See the [DEVELOPMENT.md FAQ](./DEVELOPMENT.md#how-to-authenticateauthorize-your-scripts).

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

    https://github.com/apache/whimsy/blob/master/lib/whimsy/asf/rack.rb#L56
    
 * **Cron jobs** are managed by puppet.  See [deployment](./DEPLOYMENT.md) for more
   information.

 * **NEW!** Node.js is being prototyped to improve the Board Agenda tool, stay tuned. 
   
 * **Generated JSON data** files are automatically generated into 
   the [`/public`](https://whimsy.apache.org/public/) directory, to 
   cache frequently used data for whimsy and other applications.  These 
   are usually run from a cron calling a www/roster/public_*.rb file.
   See also an [overview of data dependencies and flow](https://whimsy.apache.org/test/dataflow.cgi). 
  
 * **Data models** for many Whimsy tools are in `lib/whimsy/asf`, and 
   most **views** for tools are stored in `www`.  Note that Whimsy has 
   a wide variety of sometimes unrelated tools, so not everything 
   here uses the same models.
