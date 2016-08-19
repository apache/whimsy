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
$ gem install whimsy-asf bundler
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

 * The ldapsearch command is the standard LDAP utility on MacOSX.
 * To pick up the latest code, the above needs to be run from the directory
   you issued the `git clone` command.  Alternately, provide the full path
   to the `whimsy/lib` directory on the `ASF::LDAP.configure` command.
 * Periodically the infrastructure team reconfigures LDAP servers, which may
   require this command to be run again.
 * Alternatives to running this command can be found in step 4 of
   [DEVELOPMENT.md](https://github.com/apache/whimsy/blob/master/DEVELOPMENT.md)


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
`_www` with your local user id (this may be different than your ASF availid --
that's OK).  Replace the second `_www` with `staff`.

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

$ curl whimsy.local
<html><body><h1>It works!</h1></body></html>
```

