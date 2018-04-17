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
have to change shells if you are using csh. Bash works fine.

Verify using:

```
$ brew --version
Homebrew 1.6.0
Homebrew/homebrew-core (git revision 66e9; last commit 2018-04-11)
```

Upgrade Ruby
------------

Much of Whimsy is written in Ruby.  Install:

```
$ brew install ruby
```

Verify:

```
$ ruby -v
ruby 2.5.1p57 (2018-03-29 revision 63029) [x86_64-darwin17]
```

If you don't see 2.3.1 or later, run `hash -r` and try again.  If you previously
installed ruby via brew, you may need to run `brew upgrade ruby` instead.  If you use `rbenv` install via `rbenv install 2.5.0`


Upgrade Node.js
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
$ gem install whimsy-asf bundler mail listen
```

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

Depending on whether or not you have a GitHub account ([Apache committer setup](https://git-wip-us.apache.org/)), 
run one of the following:

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

Establish a link to this repository in a known location:

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

Running Whimsy tools locally depends on httpd.  Apple provides a copy of httpd that has [known problems](https://github.com/phusion/passenger/issues/1986), so installing a separate copy of httpd is recommended.  An optional later step in this process will forward traffic based on the hostname.

Install with LDAP support:

```
brew install apache-httpd
brew install openldap --with-sssvlv
brew reinstall -s apr-util --with-openldap
brew reinstall -s apache-httpd
```

Install passenger
-------------------

```
brew install passenger
mkdir /usr/local/opt/httpd/conf
```

create `/usr/local/opt/httpd/conf/passenger.conf` from the output from `brew info passenger` (note new location of passenger.conf file: was `/etc/apache2/other`).

 * Change `/usr/bin/ruby` to where you have Ruby installed.  If you followed the instructions above, this will be `/usr/local/bin/ruby`.  If you use rbenv or another tool to manage your Ruby installs, use that location instead.
 * Optional: add `PassengerUser _www` and `PassengerGroup _www` lines if you would like your passenger applications to run under the web user.

Configure `whimsy.local`
-------------------

`cp /srv/whimsy/config/whimsy.conf /usr/local/opt/httpd/conf/`

edit `/usr/local/opt/httpd/conf/whimsy.conf`:

   * change `:80` to `:8080`
   * change `ErrorLog` and `Custlog` to `/usr/local/var/log/httpd/whimsy_error.log` and `/usr/local/var/log/httpd/whimsy_access.log` respectively.

Complete Apache configuration
------------------

edit `/usr/local/etc/httpd/httpd.conf`:

* Uncomment each of the following lines:
    <pre>
    LoadModule proxy_module lib/httpd/modules/mod_proxy.so
    LoadModule proxy_wstunnel_module lib/httpd/modules/mod_proxy_wstunnel.so
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

Additional Notes:

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

Check that the server information includes 'Phusion_Passenger':

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

When things go wrong, check `/var/log/apache2/whimsy_error.log` and
`/var/log/apache2/error_log`.

