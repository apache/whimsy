Installation on Mac OS/X
========================

Step by step instruction on getting a full whimsy test environment up and
running on Mac OS/X.  Not all steps are required for every tool, but steps
common to many tools are included here, and additional steps required for
specific tools are linked at the bottom of these instructions.
See Also the general DEVELOPMENT.md configuration notes.

Install Homebrew
----------------

Homebrew is a package manager for OSX, which is used to install other tools.
Follow the instructions from [brew.sh](http://brew.sh/). You might
have to change shells if you are using csh. Bash works fine.  Be sure to 
read the Homebrew prerequisites; you may need part(s) of Apple's XCode.

Verify minimum version installed using:

```
$ brew --version
Homebrew 1.6.0
Homebrew/homebrew-core (git revision 66e9; last commit 2018-04-11)
```

Update using:

```
$ brew update
```

Homebrew has (as of 2019) removed options we need from two of the formulas we need.
Fix formulas for `openldap` and `apr-util` to make the required options standard.
Note that we have to remove the bottles otherwise a version of the software is downloaded that does not include the options we require.  You will need to fix these formulas and re-update brew.

```
$ cd /usr/local/Homebrew/Library/Taps/homebrew/homebrew-core/Formula
$ # edit apr-util.rb and openldap.rb to make the below diffs
$ git diff
diff --git a/Formula/apr-util.rb b/Formula/apr-util.rb
index 4dee25282..97f460398 100644
--- a/Formula/apr-util.rb
+++ b/Formula/apr-util.rb
@@ -5,24 +5,28 @@ class AprUtil < Formula
   sha256 "d3e12f7b6ad12687572a3a39475545a072608f4ba03a6ce8a3778f607dd0035b"
   revision 1
 
-  bottle do
-    sha256 "e4927892e16a3c9cf0d037c1777a6e5728fef2f5abfbc0af3d0d444e9d6a1d2b" => :mojave
-    sha256 "1bdf0cda4f0015318994a162971505f9807cb0589a4b0cbc7828531e19b6f739" => :high_sierra
-    sha256 "75c244c3a34abab343f0db7652aeb2c2ba472e7ad91f13af5524d17bba3001f2" => :sierra
-    sha256 "bae285ada445a2b5cc8b43cb8c61a75e177056c6176d0622f6f87b1b17a8502f" => :el_capitan
-  end
 
   keg_only :provided_by_macos, "Apple's CLT package contains apr"
 
   depends_on "apr"
   depends_on "openssl"
+  depends_on "openldap"
 
   def install
     # Install in libexec otherwise it pollutes lib with a .exp file.
     system "./configure", "--prefix=#{libexec}",
                           "--with-apr=#{Formula["apr"].opt_prefix}",
                           "--with-crypto",
-                          "--with-openssl=#{Formula["openssl"].opt_prefix}"
+                          "--with-openssl=#{Formula["openssl"].opt_prefix}",
+                         "--with-ldap",
+                         "--with-ldap-lib=#{Formula["openldap"].opt_lib}",
+                         "--with-ldap-include=#{Formula["openldap"].opt_include}"
     system "make"
     system "make", "install"
     bin.install_symlink Dir["#{libexec}/bin/*"]
diff --git a/Formula/openldap.rb b/Formula/openldap.rb
index bc6bde9fe..710265ec1 100644
--- a/Formula/openldap.rb
+++ b/Formula/openldap.rb
@@ -4,11 +4,11 @@ class Openldap < Formula
   url "https://www.openldap.org/software/download/OpenLDAP/openldap-release/openldap-2.4.47.tgz"
   sha256 "f54c5877865233d9ada77c60c0f69b3e0bfd8b1b55889504c650047cc305520b"
 
-  bottle do
-    sha256 "07e1f0e3ec1a02340a82259e1ace713cfb362126404575032713174935f4140e" => :mojave
-    sha256 "8901626fc45d76940dec5e516b23d81c9970f4a4a94650bdad60228d604c1b4a" => :high_sierra
-    sha256 "6dc84ff9e088116201a47adc5c3a2aab28ffd10dbab9d677d49ad7eef1ccc349" => :sierra
-  end
 
   keg_only :provided_by_macos
 
@@ -35,6 +35,7 @@ class Openldap < Formula
       --enable-refint
       --enable-retcode
       --enable-seqmod
+      --enable-sssvlv=yes
       --enable-translucent
       --enable-unique
       --enable-valsort
```
Now have Homebrew actually install the updated modules; note the -s --build-from-source flag:

```
brew install -s apr-util
brew install -s openldap
```


Upgrade Ruby
------------

Much of Whimsy is written in Ruby.  Most OSX versions include outdated ruby, so:

Verify your current ruby version:

```
$ ruby -v
ruby 2.5.1p57 (2018-03-29 revision 63029) [x86_64-darwin17]
```

You need at least version 2.4.1 to match the currently deployed Whimsy server.
If you don't see 2.3.1 or later, run `hash -r` and try again.  If you still need 
to update your ruby, proceed using one of the common ruby version managers:
Homebrew (may not work as of 2019; this is due to library updates in Ruby 2.6.x), rbenv (known to work), or rvm.

If using rbenv, install:

```
$ brew install rbenv
$ cd /srv/whimsy && rbenv install
$ rbenv init
```
Follow directions to ensure rbenv is setup in your shell(s), and double-check your ruby version. 
Note the PATH changes that `rbenv init -` configures; you'll need to duplicate it in your httpd conf later.
To use this globally when invoked through rbenv shims, you can use `rbenv global $VERSION` to set that where `$VERSION` is the version in `/srv/whimsy/.ruby-version`.
To set this system-wide, you can link the specific versions of `ruby` and `gem` in rbenv to `/usr/local/bin` like so:

```
ln -s /usr/local/bin/ruby $HOME/.rbenv/versions/2.5.5/bin/ruby
ln -s /usr/local/bin/gem $HOME/.rbenv/versions/2.5.5/bin/gem
```

Install Node.js
---------------

Install:

```
$ brew install node
$ npm install -g npm
```

Verify:

```
$ node -v
v9.11.1
$ npm -v
5.8.0
```

If you don't see v6 or higher, run `hash -r` and try again.  If you previously
installed node via brew, you may need to run `brew upgrade node` instead.


Install Ruby gem dependencies
------------

Install:

```
sudo gem install mail listen
sudo gem install bundler -n /usr/local/bin
sudo gem install nokogumbo
sudo gem install passenger sinatra kramdown
sudo gem install setup
sudo gem install ruby2js
sudo gem install rack rake
sudo gem install crass json sanitize
```

* NOTE: `sudo` not required when using rbenv

Verify:

```
$ gem list
$ bundler -v
Bundler version 1.16.1
```

Notes:

* If you are using Mac OS El Capitan or higher, you may need to `sudo gem install bundler -n /usr/local/bin`
  in order to install bundler outside of `/usr/bin`
* If you get `bundler's executable "bundle" conflicts with /usr/local/bin/bundle
  Overwrite the executable? [yN]`, respond with `y` (twice!)
* Some tools may need a [`bundle install`](DEVELOPMENT.md#running-whimsy-applications-car) run for additional gems.
* You may have trouble installing due to the dependency on nokogiri. There are
  issues with its dependencies. This page suggests some workarounds:
  https://github.com/sparklemotion/nokogiri/issues/1483
  The simplest solution may be `xcode-select --install` unless you know
  that's already configured.

Clone the Whimsy code
------------

Depending on whether or not you have a GitHub account ([Apache committer setup](https://gitbox.apache.org/)), 
use GitHub Desktop or run one of the following:

```
git clone git@github.com:apache/whimsy.git
git clone https://github.com/apache/whimsy.git
git clone https://gitbox.apache.org/repos/asf/whimsy.git
```

The first command makes things easier if you want to push to the GitHub clone
and avoid the dual authentication each time.  The third command is for pushing
to the asf hosted clone.  This only establishes the `origin`.  You can add
other remotes via commands like:

```
git remote add github git@github.com:apache/whimsy.git
git remote add asf https://gitbox.apache.org/repos/asf/whimsy.git
```

Establish a link to this repository in a known location - this step is 
optional to do basic work but required for a number of tools:

```
cd whimsy
sudo mkdir /srv
sudo ln -s `pwd` /srv/whimsy
```

Configure LDAP
--------------

Many Whimsy modules use Apache's LDAP directory.  Install:

```
$ cd /srv/whimsy
$ sudo ruby -I lib -r whimsy/asf -e "ASF::LDAP.configure"
```

Verify:

```
$ ldapsearch -x -LLL uid=rubys cn
dn: uid=rubys,ou=people,dc=apache,dc=org
cn: Sam Ruby
```

Notes: 

 * See DEVELOPMENT.md for more [LDAP configuration](DEVELOPMENT.md#ldapconfig).
 * To pick up the latest code, the above needs to be run from the directory
   you issued the `git clone` command.  Alternately, provide the full path
   to the `whimsy/lib` directory on the `ASF::LDAP.configure` command.
 * Periodically the infrastructure team reconfigures LDAP servers, which may
   require this command to be run again.
 * Alternatives to running this command can be found in step 4 of
   [DEVELOPMENT.md](https://github.com/apache/whimsy/blob/master/DEVELOPMENT.md)
 * The `ldapsearch` command is the standard LDAP utility on MacOSX.


Install Apache httpd
------------------

Running Whimsy tools locally depends on httpd.  Apple provides a copy of httpd that has [known problems](https://github.com/phusion/passenger/issues/1986), so installing a separate copy of httpd from homebrew is recommended.  An optional later step in this process will forward traffic based on the hostname.

Install with LDAP support:

```
brew install apache-httpd
brew install openldap # --with-sssvlv
brew reinstall -s apr-util # --with-openldap
brew reinstall -s apache-httpd
```
Note: if you encounter problems, double-check that the edits made to homebrew-core/Formula/\* you made earlier are still there; if you happened to brew update, they may get overwritten.

Install passenger
-------------------

```
brew install passenger
mkdir /usr/local/opt/httpd/conf
```

create `/usr/local/opt/httpd/conf/passenger.conf` from the output from `brew info passenger` (note new location of passenger.conf file: was `/etc/apache2/other`).

 * Change `/usr/bin/ruby` to where you have Ruby installed.
   * If you followed the instructions above, this will be `/usr/local/bin/ruby`.
   * If using rbenv, this should be `$HOME/.rbenv/shims/ruby`.
 * Optional: add `PassengerUser _www` and `PassengerGroup _www` lines if you would like your passenger applications to run under the web user.

Configure `whimsy.local`
-------------------

`cp /srv/whimsy/config/whimsy.conf /usr/local/opt/httpd/conf/`

edit `/usr/local/opt/httpd/conf/whimsy.conf`:

   * change `:80` to `:8080`
   * change `ErrorLog` and `Custlog` to `/usr/local/var/log/httpd/whimsy_error.log` and `/usr/local/var/log/httpd/whimsy_access.log` respectively.
   * if using rbenv, change `SetEnv` line to `SetEnv PATH ${HOME}/.rbenv/shims:/usr/local/bin:${PATH}`

Complete Apache configuration
------------------

edit `/usr/local/etc/httpd/httpd.conf`:

* Uncomment each of the following lines:
    <pre>
    LoadModule proxy_module lib/httpd/modules/mod_proxy.so
    LoadModule proxy_wstunnel_module lib/httpd/modules/mod_proxy_wstunnel.so
    LoadModule negotiation_module lib/httpd/modules/mod_negotiation.so
    LoadModule speling_module lib/httpd/modules/mod_speling.so
    LoadModule rewrite_module lib/httpd/modules/mod_rewrite.so
    LoadModule expires_module lib/httpd/modules/mod_expires.so
    LoadModule cgi_module lib/httpd/modules/mod_cgi.so
    </pre>

* Append the following:
   <pre>
    LoadModule ldap_module lib/httpd/modules/mod_ldap.so
    LoadModule authnz_ldap_module lib/httpd/modules/mod_authnz_ldap.so
    LDAPVerifyServerCert Off
    Include conf/passenger.conf
    Include conf/whimsy.conf
    ServerName whimsy.local
  </pre>


Launch the server using:

```
brew services start httpd
```

Verify:

```
$ curl -s localhost:8080 | grep '<title>'
    <title>Apache Whimsy</title>
```

This may fail on High Sierra with a [We cannot safely call it or ignore it in
the fork() child process. Crashing
instead.](https://blog.phusion.nl/2017/10/13/why-ruby-app-servers-break-on-macos-high-sierra-and-what-can-be-done-about-it/) message in your `/var/log/apache/error.log` file.  If so, do the following:

On Mojave the failure with forking occurred with Passenger and the following fixes were required.

Edit `/usr/local/opt/httpd/homebrew.mxcl.httpd.plist` and add the following:

```
<key>EnvironmentVariables</key>
<dict>
  <key>OBJC_DISABLE_INITIALIZE_FORK_SAFETY</key>
  <string>YES</string>
</dict>
```

edit `/usr/local/opt/httpd/bin/envvars`, add:

```
export OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES
```

Restart Apache httpd using:

```
apachectl restart
```

**Additional Notes:**

 * `sudo lsof -i:8080` may be helpful should you find that another process
   already has port 8080 open.
 * `apachectl restart` is how you restart apache; `brew services start` itself is for
   controlling what processes automatically start at startup.
 * If `curl` gives `Connection refused` then try kicking httpd:
    * `apachectl stop`
    * `httpd`
      * If it works, then press CTRL-C and `apachectl start`
      * If it gave you `AH00526: Syntax error on line 20 of /usr/local/etc/httpd/extra/httpd-mpm.conf`
        then you may need to [delete the LockFile section](https://apple.stackexchange.com/questions/211015/el-capitan-apache-error-message-ah00526).

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
$ curl -s whimsy.local:8080 | grep '<title>'
    <title>Apache Whimsy</title>
```

Verify:

Check that the server information includes 'Phusion\_Passenger':

```
$ curl --head whimsy.local:8080
HTTP/1.1 200 OK
Date: Thu, 08 Feb 2018 16:33:56 GMT
Server: Apache/2.4.29 (Unix) Phusion_Passenger/5.2.0
Last-Modified: Thu, 08 Feb 2018 16:30:06 GMT
ETag: "25a1-564b5ecaa5f80"
Accept-Ranges: bytes
Content-Length: 9633
Content-Type: text/html
```

Optional: forward `whimsy.local` traffic to port 8080
-------------------------

Edit `/etc/apache2/httpd.conf` and uncomment out the following lines:

```
LoadModule proxy_module libexec/apache2/mod_proxy.so
LoadModule proxy_http_module libexec/apache2/mod_proxy_http.so
```

Create `/private/etc/apache2/other/localhost.conf` with the following contents:

```
NameVirtualHost *:80

<VirtualHost *:80>
  ServerName localhost
  DocumentRoot /Library/WebServer/Documents
  <Location />
    Require all granted
  </Location>
</VirtualHost>
```

Create `/private/etc/apache2/other/whimsy.conf` with the following contents:

```
<VirtualHost *:80>
    ServerName whimsy.local

    ProxyRequests off
    ProxyPreserveHost On

    LogLevel warn
    ErrorLog /var/log/apache2/whimsy_error.log
    CustomLog /var/log/apache2/whimsy_access.log combined

    <Location />
        ProxyPass http://whimsy.local:8080/
        ProxyPassReverse http://whimsy.local:8080/
        Require all granted
    </Location>
</VirtualHost>
```

If you don't have the system httpd already running, start it with:

```
sudo launchctl load -w /System/Library/LaunchDaemons/org.apache.httpd.plist
```

If the system httpd is already running, restart it:

```
/usr/sbin/apachectl restart
```

Test:

```
$ curl -s --head localhost | grep Server
Server: Apache/2.4.28 (Unix)
$ curl -s --head whimsy.local | grep Server
Server: Apache/2.4.29 (Unix) Phusion_Passenger/5.2.0

$ curl localhost
<html><body><h1>It works!</h1></body></html>
$ curl -s whimsy.local | grep '<title>'
    <title>Apache Whimsy</title>
```


Configure sending of mail
-------------------------

Every mail delivery system appears to be different.  Once whitelisted,
`sendmail` works fine on `whimsy-vm4.apache.org`.  Others may require
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

Identify location of svn checkouts
----------------------------------

Edit `~/.whimsy` and add a list of checked out ASF repositories that may
be referenced by whimsy tools.  For example:

```
:svn:
- /Users/clr/apache/foundation
- /Users/clr/apache/documents
- /Users/clr/apache/committers
```

Note: wildcards are permitted.  The above can more economically be expressed
as:

```
:svn:
- /Users/clr/apache/*
```

Verify by visiting
[http://whimsy.local/status/svn](http://whimsy.local/status/svn).

If you have at least one entry that ends with a `*`, and the
parent directory exists and is writable, this tool
will be able to do a check-out for you.

Note that some checkouts (and possibly even some updates) may take longer than
the Apache httpd
[timeout](https://httpd.apache.org/docs/2.4/mod/core.html#timeout), which
defaults to 60 seconds, and if so, this tool won't automatically update when
the operation completes.  Should that happen, simply refresh the page to see
the changes.


Make applications restart on change
-----------------------------------

While CGI scripts and static pages (HTML, CSS, JavaScript) can be changed
and are immediately available to be served without restarting the server,
Passenger/Rack applications need to be restarted to pick up changes.  To
make this easier, whimsy has a small tool that will watch for file system
changes and restart applications that might be affected on the receipt of
the next request.

To have this tool launch automatically, copy `whimsy/config/toucher.plist` to
'~/Library/LaunchAgents/'.  Start via:

```
launchctl load ~/Library/LaunchAgents/toucher.plist
```

To verify that it is working, touch a file in an application, and verify
that `tmp/restart.txt` has been updated.  Example:

```
$ ls -l whimsy/www/board/agenda/tmp/restart.txt
$ touch whimsy/www/board/agenda/README.md
$ ls -l whimsy/www/board/agenda/tmp/restart.txt
```


Additional (application specific) configuration
-----------------------------------------------

A number of individual tools require additional configuration:

* [config/board-agenda.md](config/board-agenda.md)
* [config/secretary-workbench.md](config/secretary-workbench.md)
* [config/officers-acreq.md](config/officers-acreq.md)

Debugging
---------

When things go wrong, either check `whimsy_error.log` and `error_log` in
either `/usr/local/var/log/httpd/` or `/var/log/apache2/`. The location depends on how you have installed httpd.

