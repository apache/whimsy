Installation on Mac OS/X
========================

Step by step instruction on getting a full whimsy test environment up and
running on Mac OS/X.

Install Homebrew
----------------

Follow the instructions from [brew.sh](http://brew.sh/). You might
have to change shells if you are using csh. Bash works fine.

Verify using:

```
$ brew --version
Homebrew 0.9.9 (git revision b39eb; last commit 2016-08-18)
Homebrew/homebrew-core (git revision d20c; last commit 2016-08-18)
```

Upgrade Ruby
------------

Install:

```
$ brew install ruby
```

Verify:

```
$ ruby -v
ruby 2.3.1p112 (2016-04-26 revision 54768) [x86_64-darwin15]
```

If you don't see 2.3.1, run `hash -r` and try again.  If you previously
installed ruby via brew, you may need to run `brew upgrade ruby` instead.


Install dependencies
------------

Install:

```
$ gem install whimsy-asf bundler mail
```

Verify:

```
$ ruby -r whimsy/asf -e 'p ASF.constants'
[:Config, :Base, :Committee, :LDAP, :ETCLDAP, :LazyHash, :Person, :Group, :Service, :Mail, :SVN, :Git, :ICLA, :Authorization, :Member, :Site, :Podling, :Podlings]

$ bundler -v
Bundler version 1.12.5
```

Notes:

You may have trouble installing due to the dependency on nokogiri. There are issues
with its dependencies. This page suggests some workarounds:
https://github.com/sparklemotion/nokogiri/issues/1483

Clone whimsy
------------

Depending on whether or not you have a GitHub account, run one of the
following:

```
git clone git@github.com:apache/whimsy.git
git clone https://github.com/apache/whimsy.git
git clone https://git-dual.apache.org/repos/asf/whimsy.git
```

The first command makes things easier if you want to push to the GitHub clone
and avoid the dual authentication each time.  The third command is for pushing
to the asf hosted clone.  This only establishes the `origin`.  You can add
other remotes via commands like:

```
git remote add github git@github.com:apache/whimsy.git
git remote add asf https://git-dual.apache.org/repos/asf/whimsy.git
```


Configure LDAP
--------------

Install:

```
$ cd <path-to-git-whimsy>
$ sudo ruby -I whimsy/lib -r whimsy/asf -e "ASF::LDAP.configure"
```

Verify:

```
$ ldapsearch -x -LLL uid=rubys cn
dn: uid=rubys,ou=people,dc=apache,dc=org
cn: Sam Ruby
```

Notes: 

 * To pick up the latest code, the above needs to be run from the directory
   you issued the `git clone` command.  Alternately, provide the full path
   to the `whimsy/lib` directory on the `ASF::LDAP.configure` command.
 * Periodically the infrastructure team reconfigures LDAP servers, which may
   require this command to be run again.
 * Alternatives to running this command can be found in step 4 of
   [DEVELOPMENT.md](https://github.com/apache/whimsy/blob/master/DEVELOPMENT.md)
 * The `ldapsearch` command is the standard LDAP utility on MacOSX.


Start Apache httpd
------------------

Install:

```
sudo launchctl load -w /System/Library/LaunchDaemons/org.apache.httpd.plist
```

Verify:

```
$ curl localhost
<html><body><h1>It works!</h1></body></html>
```

Notes:

 * `sudo lsof -i:80` may be helpful should you find that another process
   already has port 80 open.
 * `sudo apachectl restart` is how you restart apache; launchctl itself is for
   controlling what processes automatically start at startup.

Configure Apache httpd to run under your user id
------------------------------------------------

First, lock down Apache so that it can only be accessed from your localhost
(using either IPv4 or IPv6).  As you will be configuring Apache httpd to be
running with your ID, this will prevent external hackers from exploiting that
code to update your filesystem and do other nasty things.

Edit `/etc/apache2/httpd.conf` using sudo and your favorite text editor.
Locate the first line that says `Require all granted`.  This should be around
line 263.  Replace that line with the following three lines:

```
<RequireAny>
  Require ip 127.0.0.1
  Require ip ::1
</RequireAny>
```

Find the next occurence of `Require all granted`.  It should now be around
line 386.  Replace it with `Require all denied`.

Now go back to the top of the file and search or `User`.  Replace the first
`_www` with your local user id.  This may be different than your ASF availid --
that's OK.  Your local user id is the response to whoami.
Replace the second `_www` with `staff`.

Save your changes.

Restart Apache httpd using `sudo apachectl restart`.

Verify that you can continue to access the server by re-issuing the following
command:

```
$ curl localhost
<html><body><h1>It works!</h1></body></html>
```

Make whimsy.local an alias for your machine
-------------------------------------------

Edit `/etc/hosts` using sudo and your favorite text editor.

Find either line that contains the word `localhost` and add `whimsy.local` to
it.  For example, if you chose what is likely to be the final line in the file
and update it, it would look like this:

```
::1             localhost whimsy.local
```

Save your changes.

Verify that you can access the server using this new alias:

```
$ curl whimsy.local
<html><body><h1>It works!</h1></body></html>
```

Install passenger
------------------------------------------------

Install:

```
$ gem install passenger
$ passenger-install-apache2-module
$ sudo apachectl restart
```

For the second step ('passenger-install-apache2-module`), you will need to
follow the instructions -- which essentially are to press enter twice and then
copy a file to specified location.  If for any reason you skip that last step,
you can redo it with the following command:

```
$ sudo bash -c 'passenger-install-apache2-module --snippet > /etc/apache2/other/passenger.conf'
```

Verify:

Check that the server information includes 'Phusion_Passenger':

```
$ curl --head whimsy.local
HTTP/1.1 200 OK
Date: Fri, 19 Aug 2016 12:23:23 GMT
Server: Apache/2.4.18 (Unix) Phusion_Passenger/5.0.30
Content-Location: index.html.en
Vary: negotiate
TCN: choice
Last-Modified: Mon, 11 Jun 2007 18:53:14 GMT
ETag: "2d-432a5e4a73a80"
Accept-Ranges: bytes
Content-Length: 45
Content-Type: text/html
```

Configure whimsy.local vhost
----------------------------

Once again, Edit `/etc/apache2/httpd.conf` using sudo and your favorite text editor.

Uncomment out the following lines:

```
LoadModule rewrite_module libexec/apache2/mod_rewrite.so

LoadModule authnz_ldap_module libexec/apache2/mod_authnz_ldap.so

LoadModule ldap_module libexec/apache2/mod_ldap.so

LoadModule expires_module libexec/apache2/mod_expires.so

LoadModule cgi_module libexec/apache2/mod_cgi.so
```

Add the following line:

```
LDAPVerifyServerCert Off
```

Copy whimsy vhost definition to your apache2 configuration:

```
sudo cp whimsy/config/whimsy.conf /private/etc/apache2/other
```

Edit `private/etc/apache2/other/whimsy.conf` and replace all occurrences of
`/Users/rubys/git/whimsy` with the path that you cloned whimsy.

Restart Apache httpd using `sudo apachectl restart`.

Verify:

+ **Static content**: Visit [http://whimsy.local/](http://whimsy.local).  You
  should see the [whimsy home page](https://whimsy.apache.org/).
+ **CGI scripts**: Visit
  [http://whimsy.local/test.cgi](http://whimsy.local/test.cgi).  You should see
  a list of environment variables.  Compare with [test.cgi on
  whimsy](https://whimsy.apache.org/test.cgi).
+ **Passenger/Rack applications**: Visit
  [http://whimsy.local/racktest](http://whimsy.local/racktest).  You should see
  a list of environment variables.  Compare with [racktest on
  whimsy](https://whimsy.apache.org/racktest).

Compare the `PATH` values with your local (command line) environment.
Various whimsy tools will make use of a number of commands (`svn`, `pdftk`)
and it is important that these tools (and the correct version of each) can
be found on the `PATH` defined to the Apache httpd web server.  If you find
you need to adjust this, edit the `SetEnv PATH` line in
`/etc/apache2/other/whimsy.conf`, restart the server and verify the path
again.


Configure sending of mail
-------------------------

Every mail delivery system appears to be different.  Once whitelisted,
`sendmail` works fine on `whimsy-vm3.apache.org`.  Others may require
passwords or may throttle the rate at which emails can be sent.

The one option that appears to work for everybody is gmail.

Create a `~/.whimsy` file, and add the following content:

```
---
:sendmail:
  delivery_method: smtp
  address: smtp.gmail.com
  port: 587
  domain: apache.org
  user_name: username
  password: password
  authentication: plain
  enable_starttls_auto: true
```

Verify this works:

```
$ ruby whimsy/tools/testmail.rb 
```

Note Gmail will just be used as a delivery mechanism, you can still
use a different address (such as your @apache.org email address) as
the *from* address.  The `domain` above should match the host portion of
the from address.  

Should your Apache user id differ from your local user id, either specify your
ASF user id as the first parameter to the testmail.rb program, or set the USER
environment variable to your ASF user id before running this script.

If this fails, check your email for a response from Google.  You may need
to approve this application.

Information on other ways to configure sending mail can be found at
[DEVELOPMENT.md](DEVELOPMENT.md#setup) step 6.


Additional (application specific) configuration
-----------------------------------------------

A number of individual tools require additional configuration:

* [config/board-agenda.md](config/board-agenda.md)
* [config/secretary-workbench.md](config/secretary-workbench.md)

Debugging
---------

When things go wrong, check `/var/log/apache2/whimsy_error.log` and
`/var/log/apache2/error_log`.

