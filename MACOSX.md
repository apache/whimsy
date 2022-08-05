Installation on Mac OS/X
========================

Step by step instruction on getting a full Whimsy test environment up and
running on Mac OS/X.  Not all steps are required for every tool, but steps
common to many tools are included here, and additional steps required for
specific tools are linked at the bottom of these instructions.
See also the general [DEVELOPMENT.md](./DEVELOPMENT.md) configuration notes.

:dizzy: **New!** For a simpler way to setup a Mac OSX machine, please 
check out the [setupmymac script](./SETUPMYMAC.md), which automates 
configuring and keeping updated a local Whimsy instance.

Install Homebrew
----------------

Homebrew is a package manager for OSX, which is used to install other tools.
Follow the instructions from [brew.sh](https://brew.sh/). You might
have to change shells if you are using csh. Bash and zsh work fine.  Be sure to
read the Homebrew prerequisites; you may need part(s) of Apple's XCode.

Verify minimum version installed using:

```
$ brew --version
Homebrew 2.1.16
Homebrew/homebrew-core (git revision 274de; last commit 2019-11-12)
```

Update using:

```
$ brew update
```

Upgrade Ruby (if needed)
------------------------

Much of Whimsy is written in ruby.  Versions of OSX prior to 10.15 (Catalina)
include an outdated version of ruby.

Verify your current ruby version:

```
$ ruby -v
ruby 2.6.3p62 (2019-04-16 revision 67580) [universal.x86_64-darwin19]
```

You need at least version 2.4.1 to match the currently deployed Whimsy server.
If you don't see 2.3.1 or later, run `hash -r` and try again.  If you still need 
to update your ruby, proceed using one of the common ruby version managers:
rbenv (known to work), or rvm.

If using rbenv, install:

```
$ brew install rbenv
$ cd /srv/whimsy && rbenv install
$ rbenv init
```
Follow directions to ensure rbenv is setup in your shell(s), and double-check your ruby version. 
Note the PATH changes that `rbenv init -` configures; you'll need to duplicate it in your httpd conf later.
To use this globally when invoked through rbenv shims, you can use `rbenv global $VERSION` to set that where `$VERSION` is the version in `/srv/whimsy/.ruby-version`.
[TODO: describe how to set .ruby-version]
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
v12.12.0
$ npm -v
6.11.3
```

If you don't see v6 or higher, run `hash -r` and try again.  If you previously
installed node via brew, you may need to run `brew upgrade node` instead.

Install Puppeteer
-----------------
There are a couple of scripts that require the Puppeteer node module.
Installing this is optional, as the scripts are currently only used for cron jobs.
```
npm install -g puppeteer
```
To enable easy access to the module, define the following environment variable:
```export NODE_PATH=$(npm root -g)```
For example this may produce
```NODE_PATH="/usr/local/lib/node_modules"```
Note: on Ubuntu, it looks as though the default is ```/usr/lib/node_modules```

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

Establish a link to this repository in a known location.  First instructions
for Mac OSX version < 10.15 (Mojave, High Sierra, Sierra, ...):

```
cd whimsy
sudo mkdir /srv
sudo ln -s `pwd` /srv/whimsy
```

Alternate instructions for Mac OSX version >= 10.15 (Catalina):

```
sudo mkdir /var/whimsy
echo -e 'srv\t/var/whimsy' | sudo tee -a /etc/synthetic.conf
```

Reboot the machine, then:

```
cd whimsy
sudo ln -s `pwd` /srv/whimsy
```

Note: if you had previously created a <tt>/srv</tt> directory and it goes
missing when you upgrade to Catalina, the previous contents can be found in
<tt>"/Users/Shared/Relocated Items/Security"</tt>.

Install Ruby gem dependencies
------------

Install:

```
cd /srv/whimsy
bundle install
```

Verify:

```
$ gem list
$ bundler -v
Bundler version 1.17.2
```

Notes:

* If bundler is not installed, you may need to run `sudo gem install bundler`.
  If this doesn't work, try `sudo gem install bundler -n /usr/local/bin`
  in order to install bundler outside of `/usr/bin`
* If you get `bundler's executable "bundle" conflicts with /usr/local/bin/bundle
  Overwrite the executable? [yN]`, respond with `y` (twice!)
* Some tools may need a [`bundle
  install`](DEVELOPMENT.md#running-whimsy-applications-car) run for additional
  gems.  Simply change directory to the tool you wish to develop, and run
  `bundle install` in that directory.  If you want to install all of the
  dendencies for all of the whimsy tools, run `rake update` in the top whimsy
  directory.
* You may have trouble installing due to the dependency on nokogiri. There are
  issues with its dependencies. This page suggests some workarounds:
  https://github.com/sparklemotion/nokogiri/issues/1483
  The simplest solution may be `xcode-select --install` unless you know
  that's already configured.

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


Start Apache httpd
------------------

*Note* as an alternative to configuring and starting the version of httpd which
is provided with MacOSX, you can install a separate version using Homebrew.
Those instructions can be found in an [older version of these
instructions](https://github.com/apache/whimsy/blob/cbe00a45eb949cec8a6798f1172c64166a56e518/MACOSX.md#clone-the-whimsy-code),
specifically, the Install Homebrew, Install Apache httpd, Install passenger,
Configure whimsy.local, Complete Apache configuration, Make whimsy.local an
alias for your machine, and Optional: forward whimsy.local traffic to port 8080
steps.

Running Whimsy tools locally depends on httpd.  Apple provides a copy of httpd that that you can configure and start.

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
 * If `curl` gives `Connection refused` then try kicking httpd:
    * `sudo /usr/sbin/apachectl stop`
    * `sudo /usr/sbin/httpd`
      * If it works, then press CTRL-C and `sudo /usr/sbin/apachectl start`
      * If it gave you `AH00526: Syntax error on line 20 of /private/etc/apache2/extra/httpd-mpm.conf`
        then you may need to [delete the LockFile section](https://apple.stackexchange.com/questions/211015/el-capitan-apache-error-message-ah00526).

Configure Apache httpd to run under your user id
------------------------------------------------

First, lock down Apache so that it can only be accessed from your localhost
(using either IPv4 or IPv6).  As you will be configuring Apache httpd to be
running with your ID, this will prevent external hackers from exploiting that
code to update your filesystem and do other nasty things.

Edit `/etc/apache2/httpd.conf` using sudo and your favorite text editor.
Locate the first line that says `Require all granted`.  This should be around
line 263 at the end of the section `Directory "/Library/WebServer/Documents"` or similar
Replace that line with the following four lines:

```
<RequireAny>
  Require ip 127.0.0.1
  Require ip ::1
</RequireAny>
```

Find the next occurrence of `Require all granted`.  It should now be around
line 386 in the section `Directory "/Library/WebServer/CGI-Executables` or similar
Replace it with `Require all denied`.

Now go back to the top of the file and search for `User`.  Replace the first
`_www` with your local user id.  This may be different than your ASF availid --
that's OK.  Your local user id is the response to `whoami`.
Replace the second `_www` with `staff` (that's the group name).

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

Follow the [Installing Passenger + Apache on Mac OS X](https://www.phusionpassenger.com/library/install/apache/install/oss/osx/) instructions, which are summaried below:.

Install:

```
$ brew install passenger
$ brew info passenger
```

For the second step (`brew info passenger`), you will need to
follow the instructions -- which essentially is to copy a few lines to
to a specified location, typically `/etc/apache2/other/passenger.conf`.

If your ruby is installed in `/usr/local/bin`, change the last line to

```
PassengerDefaultRuby /usr/local/bin/ruby
```

Likewise, if you used `rbenv` to manage your ruby install, point to that location instead.  This should be `$HOME/.rbenv/shims/ruby`.

Optional: add `PassengerUser _www` and `PassengerGroup _www` lines if you would like your passenger applications to run under the web user.


Restart the server:

```
sudo apachectl restart
```

Verify:

Check that the server information includes 'Phusion_Passenger':

```
$ curl --head whimsy.local
HTTP/1.1 200 OK
Date: Wed, 13 Nov 2019 19:37:12 GMT
Server: Apache/2.4.41 (Unix) Phusion_Passenger/6.0.4
Content-Location: index.html.en
Vary: negotiate
TCN: choice
Last-Modified: Thu, 29 Aug 2019 05:05:59 GMT
ETag: "2d-5913a76187bc0"
Accept-Ranges: bytes
Content-Length: 45
Content-Type: text/html
```

This may fail on High Sierra with a [We cannot safely call it or ignore it in
the fork() child process. Crashing
instead.](https://blog.phusion.nl/2017/10/13/why-ruby-app-servers-break-on-macos-high-sierra-and-what-can-be-done-about-it/) message in your `/var/log/apache/error.log` file.  If so, do the following:

```
cp /System/Library/LaunchDaemons/org.apache.httpd.plist /Library/LaunchDaemons/
```

Edit ` /Library/LaunchDaemons/org.apache.httpd.plist` and add the following to
`EnvironmentVariables/Dict`:

```
    <key>OBJC_DISABLE_INITIALIZE_FORK_SAFETY</key>
    <string>YES</string>
```

Finally:

```
sudo launchctl unload /System/Library/LaunchDaemons/org.apache.httpd.plist
sudo launchctl load -w /Library/LaunchDaemons/org.apache.httpd.plist
```

N.B. Because of System Integrity Protection (SIP), it's not possible to edit files under /System.
So the change is made to a copy. 
However the original location is baked into apachectl which is also protected by SIP.
This means apachectl ignores the change.
A work-round for this is to create an updated copy of apachectl somewhere further up the path.
 
Configure whimsy.local vhost
----------------------------

Once again, Edit `/etc/apache2/httpd.conf` using sudo and your favorite text editor.

Uncomment out the following lines:

```
LoadModule proxy_module libexec/apache2/mod_proxy.so

LoadModule proxy_wstunnel_module libexec/apache2/mod_proxy_wstunnel.so

LoadModule speling_module libexec/apache2/mod_speling.so

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

Also from the root of your whimsy git checkout, make a `/srv/cache` directory
owned by you, and establish a symbolic link to your whimsy git clone directory:

```
sudo mkdir -p /srv/cache
sudo chown `id -un`:`id -gn` /srv/cache
sudo ln -s `pwd` /srv/whimsy
```

Copy whimsy vhost definition to your apache2 configuration:

```
sudo cp /srv/whimsy/config/whimsy.conf /private/etc/apache2/other
```

Note: if you reside outside North America you may wish to use the EU LDAP server
by changing the references in the whimsy.conf file from
ldaps://ldap-us.apache.org:636/
to
ldaps://ldap-eu.apache.org:636/

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

Every mail delivery system appears to be different.  Once configured,
`sendmail` works fine on `whimsy-vm6.apache.org`.  Others may require
passwords or may throttle the rate at which emails can be sent.

The one option that appears to work for everybody is GMail.

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
'~/Library/LaunchAgents/' and have launchctl load it:

```
mkdir -p ~/Library/LaunchAgents
cp /srv/whimsy/config/toucher.plist ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/toucher.plist
```

**Note**: Adjust the path to `ruby` in `toucher.plist` if necessary.  If you
make this change after you have loaded the script, unload then reload it.

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
