Preface
=======

Whimsy is a set of independent tools and a common library which typically will
need to access various ASF SVN directories and/or LDAP.  To do development and
testing, you will need access to a machine on which you are willing to install
libraries which do things like access LDAP, XML parsing, composing mail and
the like.  While some tools may work on Microsoft Windows, many don't
currently.  Alternatives include a Docker image or a Vagrant VM.

The primary advantage of using an image or a VM is isolation.  The primary
disadvantage is that you will need to install your SVN credentials there and
arrange to either duplicate or mount your SVN directories.

Overview
========

This directory has two main subdirectories...

1. "asf" contains the "model", i.e., a set of classes which encapsulate access
   to a number of data sources such as LDAP, ICLAs, auth lists, etc.  This
   code originally was developed as a part of separate tools and was later
   refactored out into a common library.  Some of the older tools don't fully
   make use of this refactoring.

2. "www" contains the "view", largely a set of cgi scripts that produce HTML.
   Generally a cgi script is self contained, including all of the CSS,
   scripts, AJAX logic (client and server), SVG images, etc.  A single script
   may also produce a set (subtree) of web pages. 

   Some of the scripts (like the roster tool) are long running servers.  The
   board agenda tool is currently hosted on github, but this will be
   consolidated to the consolidated svn repository once 
   [INFRA-10399](https://issues.apache.org/jira/browse/INFRA-10399) 
   is complete.

Setup
=====

This section is for those desiring to run a whimsy tool on their own machine.
Skip this section if you are running a Docker container or a Vagrant VM.

1. The ruby version needs be ruby 1.9.3 or higher.  Verify with 'ruby -v'.
   If you use a system provided version of Ruby, you may need to prefix
   certain commands (like gem install) with 'sudo'.  Alternatives to using
   the system provided version include using a Ruby version manager like
   rbenv or rvm.  Rbenv generally requires you to be more aware of what you
   are doing (e.g., the need for shims).  While rvm tends to be more of a set
   and forget operation, it tends to be more system intrusive (e.g. aliasing
   'cd' in bash).
 ## Links
 1. [Understanding Shims](https://github.com/sstephenson/rbenv#understanding-shims)
 2. [Understanding Binstubs](https://github.com/sstephenson/rbenv/wiki/Understanding-binstubs)
 3. [Ruby Version Manager](https://rvm.io/)

2. Make sure that the whimsy-asf gem installed.  If it is not, run

  `gem install whimsy-asf`

3. current SVN checkouts of various repositories are made (or linked to from)
   `/home/whimsysvn/svn`

```
   svn co --depth=files https://svn.apache.org/repos/private/foundation
```

   You can specify an alternate location for these directories by placing
   a configuration file named `.whimsy` in your home directory.  The format
   for this file is YAML, and an example (be sure to include the dashed
   lines):

```
     :svn:
     - /home/rubys/svn/foundation
     - /home/rubys/svn/committers
```

4. Access to LDAP requires configuration, and a cert.
 1. The model code determines what host and port to connect to by parsing
      either `/etc/ldap/ldap.conf` or `/etc/ldap/ldap.conf` for a line that looks
      like the following:
        `uri     ldaps://ldap1-us-east.apache.org:636`

 2. A `TLS_CACERT` can be obtained via either of the following commands:

        `ruby -r whimsy/asf -e "puts ASF::LDAP.cert"`
        `openssl s_client -connect ldap1-us-east.apache.org:636 </dev/null`

      Copy from BEGIN to END inclusive into the file 
      `/etc/ldap/asf-ldap-client.pem`.  Point to the file in
      `/etc/ldap/ldap.conf` with a line like the following:

     ```   TLS_CACERT      /etc/ldap/asf-ldap-client.pem```

      N.B. OpenLDAP uses /etc/openldap/ instead of /etc/ldap/ 
      Adjust the paths above as necessary
 
      These above updates can be done for you with the following command:

        `sudo ruby -r whimsy/asf -e "ASF::LDAP.configure"`

      Note: the certificate is needed because the LDAP hosts use a self-signed
      certificate

5. Verify that the configuration is correct by running:

   `ruby examples/board.rb`

   See comments in that file for running the script as a standalone server.

Further Reading
===============

An [example](https://github.com/rubys/whimsy-agenda#readme) of a complete tool 
that makes full use of the library factoring, has a suite of test cases, and 
client componentization (using ReactJS), and provides instructions for setting 
up both a Docker component and a Vagrant VM:

If you would like to understand how the view code works, you can get started
by looking at a 
few of the [Wunderbar demos](https://github.com/rubys/wunderbar/tree/master/demo) 
and [README](https://github.com/rubys/wunderbar/blob/master/README.md).
