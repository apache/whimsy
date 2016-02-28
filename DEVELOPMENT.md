Preface
=======

Whimsy is a set of independent tools and a common library which typically will
need to access various ASF SVN directories and/or LDAP.  To do development and
testing, you will need access to a machine on which you are willing to install
libraries which do things like access LDAP, XML parsing, composing mail and
the like.  While some tools may work on Microsoft Windows, many don't
currently.  Alternatives include a Docker image, a custom Vagrant VM, and
a Kitchen/Puppet managed Vagrant VM.

The primary advantage of using an image or a VM is isolation.  The primary
disadvantage is that you will need to install your SVN credentials there and
arrange to either duplicate or mount your SVN directories.

Overview
========

This directory has two main subdirectories...

1. [lib/whimsy/asf](lib/whimsy/asf) contains the "model", i.e., a set of classes
   which encapsulate access
   to a number of data sources such as LDAP, ICLAs, auth lists, etc.  This
   code originally was developed as a part of separate tools and was later
   refactored out into a common library.  Some of the older tools don't fully
   make use of this refactoring.

2. [www](www) contains the "view", largely a set of CGI scripts that produce HTML.
   Generally a CGI script is self contained, including all of the CSS,
   scripts, AJAX logic (client and server), SVG images, etc.  A single script
   may also produce a set (subtree) of web pages.

   Some of the directories (like the roster tool) contain [rack](http://rack.github.io/)
   applications.  These can be run independently, or under the Apache web server through
   the use of [Phusion Passenger](https://www.phusionpassenger.com/).

Setup
=====

This section is for those desiring to run a whimsy tool on their own machine.
Skip this section if you are running a Docker container or a Vagrant VM.

1. The ruby version needs be ruby 1.9.3 or higher.  Verify with `ruby -v`.
   If you use a system provided version of Ruby, you may need to prefix
   certain commands (like gem install) with `sudo`.  Alternatives to using
   the system provided version include using a Ruby version manager like
   rbenv or rvm.  Rbenv generally requires you to be more aware of what you
   are doing (e.g., the need for shims).  While rvm tends to be more of a set
   and forget operation, it tends to be more system intrusive (e.g. aliasing
   'cd' in bash).

    For more information:

    1. [Understanding Shims](https://github.com/sstephenson/rbenv#understanding-shims)
    2. [Understanding Binstubs](https://github.com/sstephenson/rbenv/wiki/Understanding-binstubs)
    3. [Ruby Version Manager](https://rvm.io/)


2. Make sure that the `whimsy-asf` and `bundler` gems are installed:

  `gem install whimsy-asf bundler`

3. current SVN checkouts of various repositories are made (or linked to from)
   `/srv/svn`

        svn co --depth=files https://svn.apache.org/repos/private/foundation

   You can specify an alternate location for these directories by placing
   a configuration file named `.whimsy` in your home directory.  The format
   for this file is YAML, and an example (be sure to include the dashed
   lines):

        :svn:
        - /home/rubys/svn/foundation
        - /home/rubys/svn/committers

4. Access to LDAP requires configuration, and a cert.

 1. The model code determines what host and port to connect to by parsing
      either `/etc/ldap/ldap.conf` or `/etc/openldap/ldap.conf` for a line that
      looks like the following:
        `uri     ldaps://ldap1-us-east.apache.org:636`

 2. A `TLS_CACERT` can be obtained via either of the following commands:

        `ruby -r whimsy/asf -e "puts ASF::LDAP.cert"`<br/>
        `openssl s_client -connect ldap1-us-east.apache.org:636 </dev/null`

      Copy from `BEGIN` to `END` inclusive into the file
      `/etc/ldap/asf-ldap-client.pem`.  Point to the file in
      `/etc/ldap/ldap.conf` with a line like the following:

     ```   TLS_CACERT      /etc/ldap/asf-ldap-client.pem```

      N.B. OpenLDAP on Mac OS/X uses `/etc/openldap/` instead of `/etc/ldap/`
      Adjust the paths above as necessary.  Additionally ensure that
      that `TLS_REQCERT` is set to `allow`.

      Note: the certificate is needed because the ASF LDAP hosts use a
      self-signed certificate.

   All these updates can be done for you with the following command:

        sudo ruby -r whimsy/asf -e "ASF::LDAP.configure"

   These above command can also be used to update your configuration as
   the ASF changes LDAP servers.

5. Verify that the configuration is correct by running:

   `ruby examples/board.rb`

   See comments in that file for running the script as a standalone server.

Running Scripts/Applications
============================

If there is a `Gemfile` in the directory containing the script or application
you wish to run, dependencies needed for execution can be installed using the
command `bundle install`.

1. CGI applications can be run from a command line, and produce output to
   standard out.  If you would prefer to see the output in a browser, you
   will need to have a web server configured to run CGI, and a small CGI
   script which runs your application.  For CGI scripts that make use of
   wunderbar, this script can be generated and installed for you by
   passing a `--install` option on the command, for example:

       ruby examples/board.rb --install=~/Sites/

   Note that by default CGI scripts run as a user with a different home
   directory very little privileges.  You may need to copy or symlink your
   `~/.whimsy` file and/or run using
   [suexec](http://httpd.apache.org/docs/current/suexec.html).

2. Rack applications can be run as a standalone web server.  If a `Rakefile`
   is provided, the convention is that `rake server` will start the server,
   typically with listeners that will automatically restart the application
   if any source file changes.  If a `Rakefile` isn't present, the `rackup`
   command can be used to start the application.

   If you are testing an application that makes changes to LDAP, you will
   need to enter your ASF password.  To do so, substiture `rake auth server`
   for the `rake server` command above.  This will prompt you for your
   password.  Should your ASF availid differ from your local user id,
   set the `USER` environment variable prior to executing this command.

Advanced configuration
======================

Note: these instructions are for Ubuntu.  Tailor as necessary for Mac OSX or
Red Hat.

Setting things up so that the entire whimsy website is available as
http://localhost/whimsy/:

1. Add an alias

        Alias /whimsy /srv/whimsy/www
        <Directory /srv/whimsy/www>
           Order allow,deny
           Allow from all
           Require all granted
           Options Indexes FollowSymLinks MultiViews ExecCGI
           MultiViewsMatch Any
           DirectoryIndex index.html index.cgi
           AddHandler cgi-script .cgi
        </Directory>

2. Configure `suexec` by editing `/etc/apache2/suexec/www-data`:

       /srv
       public_html

3. Install passenger by running either running 
   `passenger-install-apache2-module` and following its instructions, or
   by visiting https://www.phusionpassenger.com/library/install/apache/install/oss/.

4. Configure individual rack applications:

       Alias /whimsy/board/agenda/ /srv/whimsy/www/board/agenda
       <Location /whimsy/board/agenda>
         PassengerBaseURI /whimsy/board/agenda
         PassengerAppRoot /srv/whimsy/www/board/agenda
         PassengerAppEnv development
         Options -Multiviews
       </Location>

5. (Optional) run a service that will restart your passenger applications
   whenever the source to that application is modified by creating a
   `~/.config/upstart/whimsy-listener` file with the following contents:

       description "listen for changes to whimsy applications"
       start on dbus SIGNAL=SessionNew
       exec /srv/whimsy/tools/toucher

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
