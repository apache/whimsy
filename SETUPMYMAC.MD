If you have a MacBook you undoubtedly have never used LDAP on it, have a
version of the Ruby programming language installed that you haven't used and
the Apache httpd web server disabled.  Why not put them to use?

It is easy, run the following two commands:

    git clone git@github.com:apache/whimsy.git
    whimsy/config/setupmymac

This will prompt you for your password a few times, and if you are running
macOS Catalina will even require you to reboot your machine at one point.

Once complete, you will have a virtual host defined as `whimsy.local` that
you can access in your web browser.

What you don't have is the various svn repostories checked out that you will
need.  For example, if you go to the board agenda application, after you provide your Apache LDAP user and password, you will see a screen showing an error:

    Unable to find svn checkout for https://svn.apache.org/repos/private/foundation/board (foundation_board) (Exception)

To correct this, do the following:

    cd /srv/svn
    svn co https://svn.apache.org/repos/private/foundation/board foundation_board

Now you will have the board agenda tool up and running, but over time you will
find that you need more svn repositories checked out.  You can repeat this
process each time, or check out everything you possibly might ever need (which
currently required 93G! - something Sebb is working on getting down) with the =
following command:

    cd /srv/svn/whimsy
    rake svn:update

Don't want to instal things on your machine?  If you have Docker installed, you
can use that instead, simply pass `--docker` to the `setupmymac` command above
and you will have a Docker image created.  This will take longer and require
more disk space, runs slower, and is less convenient, but is more secure, more
closely matches how the production whimsy server is configured, and can easily
be removed when done.  You start the server with the following commands:

    cd /srv/whimsy
    rake docker:up

When running on Docker, you will access the whimsy server using
`http://localhost:1999`.  You can edit your source code on your Mac machine
using your favorite IDE.  If you need to "shell" into the Docker container
(perhaps to view a log file), you can do so:

    cd /srv/whimsy
    rake docker:exec

The Docker configuration is new and hasn't been heavily tested, so there
likely will be some problems.  Join us on
[dev@whimsical.apache.org](https://lists.apache.org/list.html?dev@whimsical.apache.org), or even better, provide a pull request!

You can even switch back and forth (using the same checked out svn files) by
rerunning `setupmymac` again with a different option.  Once you have both
configurations set up.   This will change permissions on a few files, but
everything else is the same.

If you want to know what is going on under the covers with the setupmymac
scripts, visit either the [macOS](./MACOSX.md) or [Docker](./DOCKER.md)
instructions.
