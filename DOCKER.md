Docker execution instructions
=============================

:dizzy: **New!** For a simpler way to setup a Mac OSX machine, please
check out the [setupmymac script](./SETUPMYMAC.md), which automates
configuring and keeping updated a local whimsy instance with Docker.

This is experimental at this point.

Do *NOT* proceed unless you are comfortable with the notion of containers,
images, Dockerfiles, Volumes, Port Forwarding, and likely Docker Compose.

If, however, this describes you, it is hoped that these steps will enable you
to run a full Whimsy system inside a container on your development machine.
You can edit files inside your favorite IDE on your host machine.

Prerequisites
-------------

You will need Docker, git, and subversion.  And approximately 3 GB of
disk space

Direct link to [docker for
macOS](https://download.docker.com/mac/stable/Docker.dmg) (this avoids the
need to login to Docker Hub), or install via:

    $ brew cask install docker
    $ open /Applications/Docker.app # this starts Docker

A development class machine and a high speed internet connection would
be in order.  Some things appear to perform well, other things perform
noticeably slower than a native (non-container) installation of whimsy.

You will also need to ensure the subversion [file system
format](https://www.visualsvn.com/support/topic/00135/#FilesystemFormat)
used by the host machine matches the format used by the container.  Currently
macOS Catalina/Xcode provides svn 1.10.4 and the Dockerfile downloads the
latest 1.10 version (currently 1.10.6).

Finally, a note on password stores.  Inside ~/.subversion/config, you will see
a list of available stores, which currently is `gnome-keyring`, `kwallet`,
`gpg-agent`, `keychain`, and `windows-cryptoapi`.  The only ones that are
available to an Ubuntu container are ones marked as for "Unix-like systems".
If you chose another (e.g., keychain) then you will either need to do all of
your svn checkouts and updates from the host or you will be prompted for your
password if you attempt to do these operations from within the container.

Installation instructions
-------------------------

* Create an empty directory.  Note: while you _can_ use an existing clone of
  Whimsy (and in particular, you _may_ be able to use the `/srv` directories
  defined by the [macOS](MACOSX.md) instructions), be aware of the following:
    * Files in the parent directory of the Whimsy clone may be created,
      overwritten, or deleted by this process.
    * The `svn` and `git` sub-directories cannot be links to another part of
      host file system outside of your home directory as those files will not
      be visible to the container.
* `cd` into that directory
* `echo ":root: ." >.whimsy`
* `git clone git@github.com:apache/whimsy.git` OR
* `git clone https://github.com/apache/whimsy.git` (whichever works best for you)
* `create .bash_aliases` if required - this will be picked up by the root user
* `cd whimsy`
* Start Docker if necessary: `$ open /Applications/Docker.app`
* `rake docker:update` # this runs docker:build and updates any Gems
* `rake svn:update git:pull` # This updates the Whimsy data sources
* `rake docker:up`
* visit `http://localhost:1999/` in your favorite browser

To get a shell on the container, open a terminal console in the work directory
and run `rake docker:exec`. The container must already be running.

Note: the initial run of the `rake docker:update` step will take a long time as
it will need to download and install all of the Ubuntu packages,
build and install Passenger, as well as update all the Ruby Gems.
The good news is that this can be entirely unattended as there
will be no prompts required during this process.
The command does not need to be repeated each time you want to start the container,
but should be repeated from time to time to fetch updated sources.

If you wish to create the Ubuntu image separately, run `rake docker:build`
(this is invoked as part of docker:update)
This should be re-run if you update any of the resources used for the build,
e.g. files in docker-config and the Dockerfile


The `rake svn:update git:pull` step updates the SVN and Git repos used by Whimsy.
The container does not automatically update these (unlike the live installation),
so the step should be performed as necessary before starting the container to ensure the
data is sufficiently up-to-date. This requires karma to fetch some of the files.

This should be enough to get most of Whimsy working.  It is not
known yet what functions work and what functions do not.

Installation layout
-------------------
The `docker-compose.yml` has the following mounts:

container path      host path
/srv                directory chosen in step 1

These are currently disabled, see https://github.com/apache/whimsy/issues/119
/root/.subversion   $HOME/.subversion
/root/.ssh          $HOME/.ssh

You can edit the files in these directories using your host tools.
If any of the configuration files under .subversion etc contain absolute references to
files (such as CA certificates), these will need to be fixed somehow (e.g. create links on
the container)

Note on Repositories
--------------------

If you don't want to check out all of the repositories, omit the
`rake docker:update svn:update git:pull`, and only checkout/clone
the repositories that you need.  You can find the complete list in
[repository.yml](./repository.yml).

If you haven't checked out a repository that you need to run a specific tool,
you will generally see an exception like the following in your logs:

    Unable to find svn checkout for https://svn.apache.org/repos/private/foundation/board (foundation_board) (Exception)

To correct this, do the following:

    cd /srv/svn
    svn co https://svn.apache.org/repos/private/foundation/board foundation_board

Testing email
-------------

The following command can be used to run a dummy smtp server on port 1025:
`python3 -u -m smtpd -n -c DebuggingServer localhost:1025`

It can be tested with:
`tools/testmail.rb <userid>`

[Note that Whimsy does not generally send emails unless it detects that it is the active server.]

Known not to work (ToDos)
-------------------------

* Board agenda web socket (used to communicate updates from the server to
  browsers)
* Automatic restarting of passenger based tools when source code changes are
  made.

Uninstallation procedures
-------------------------

* Exit out of any running containers
* Remove the entire directory created as step 1 of the installation
  instructions.
* `docker image rm whimsy-web`
* `docker image prune -f`
* `docker container prune -f`
