If you have a MacBook you undoubtedly have never used LDAP on it, have a
version of the Ruby programming language installed that you also haven't used
much, and the Apache httpd web server is disabled.  Why not put them to use?

It is easy, run the following two commands:

    git clone git@github.com:apache/whimsy.git
    whimsy/config/setupmymac

This will prompt you for your password a few times, and if you are running
macOS Catalina will even require you to reboot your machine at one point.

Once complete, you will have a virtual host defined as `whimsy.local` that
you can access in your web browser.  The whole process should take about
five minutes, possibly less if you already have things like `brew` installed.

Don't want to instal things on your machine?  If you have Docker installed, you
can use that instead, simply pass `--docker` to the `setupmymac` command above
and you will have a Docker image created.  This will take longer, require more
disk space, runs slower, and is less convenient, but is more secure, more
closely matches how the production whimsy server is configured, and can easily
be removed when done.  Once complete, you start the server with the following
commands:

    cd /srv/whimsy
    rake docker:up

When running on Docker, you will access the whimsy server using
`http://localhost:1999`.  You can edit your source code on your Mac machine
using your favorite IDE.  If you need to "shell" into the Docker container
(perhaps to view a log file?), you can do so:

    cd /srv/whimsy
    rake docker:exec

The Docker configuration is new and hasn't been heavily tested, so there
likely will be some problems.  Join us on
[dev@whimsical.apache.org](https://lists.apache.org/list.html?dev@whimsical.apache.org), or even better, provide a pull request!

You can even switch back and forth (using the same checked out svn files and
whimsy source code) by rerunning `setupmymac` again with a different option.
Once you have both configurations set up running this command again will change
permissions on a few files, but generally will leave everything else is the
same.  If you want to update more (say, to get a new version of `passenger`),
there are options to do that, enter `whimsy/config/setupmymac --help` for
details.  Pass `-all` to update everything.

If you want to know what is going on under the covers with the setupmymac
scripts, visit either the [macOS](./MACOSX.md) or [Docker](./DOCKER.md)
instructions.
