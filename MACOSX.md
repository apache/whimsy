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
