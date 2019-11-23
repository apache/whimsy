Docker execution instructions
=============================

This is experimental at this point.

These steps will enable you to run a full Whimsy system inside a
container on your development machine.  You can edit files inside
your favorite IDE on your host machine.

Prerequisites
-------------

You will need Docker, git, and subversion.  And approximately 30Gb of
disk space (over 20Gb of which will be to have a copy of iclas, cclas,
and grants for the secretary workbench; perhaps in the future these
could be made optional).

Direct link to [docker for
macOS](https://download.docker.com/mac/stable/Docker.dmg) (this avoids the
need to login to Docker Hub).

A development class machine and a high speed internet connection would
be in order.  Some things appear to perform well, other things perform
noticeably slower than a native (non-container) installation of whimsy.

You will also need to ensure the subversion [file system
format](https://www.visualsvn.com/support/topic/00135/#FilesystemFormat) of the
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
* `touch .whimsy`
* `git clone git@github.com:apache/whimsy.git` (or alternately
  `git clone https://github.com/apache/whimsy.git`)
* `cd whimsy`
* Start Docker if necessary
* `rake docker:update svn:update git:pull`
* `rake docker:up`
* visit `http://localhost:1999/` in your favorite browser

To get a shell on the container, open a terminal console in the work directory
and run `rake docker:exec`.

Note: the `rake docker:update svn:update git:pull` step will take a long time as
it will need to download and install all of the Ubuntu packages, Ruby gems,
build and install Passenger, checkout numerous svn repositories and two git
repositories.  The good news is that this can be entirely unattended as there
will be no prompts required during this process (except possibly for SVN
updates).

If you wish to create the Ubuntu image separately, run `rake docker:build`
(this is invoked as part of docker:update)

This should be enough to get the board agenda tool to launch.  It is not
known yet what functions work and what functions do not.

Installation layout
-------------------
The `docker/docker-compose.yml` has the following mounts:

container path      host path
/srv                directory chosen in step 1
/root/.subversion   $HOME/.subversion
/root/.gitconfig    $HOME/.gitconfig
/root/.ssh          $HOME/.ssh

You can edit the files in these directories using your host tools.
If any of the configuration files under .subversion etc contain absolute references to
files (such as CA certificates), these will need to be fixed somehow (e.g. create links on
the container)

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

