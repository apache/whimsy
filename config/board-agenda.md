Configuring the Board Agenda

Install Dependencies
--------------------

Change directory to `whimsy/www/board/agenda`

Run:

```
$ bundle install
```

Look for a line that says either `Bundle complete!` or `Bundle updated!`.

Indentify where files are to be found
-------------------------------------

Edit `~/.whimsy`

Define a path to a directory where work files will be placed.  For example:

```
:agenda_work: /Users/rubys/tmp/agenda
```

Add paths to foundation board and committers board directory.  For example:

```
:svn:
- /Users/rubys/svn/foundation/board
- /Users/rubys/svn/committers/board
```

Note: wildcards may be used, and providing a path to a higher level directory
within the same svn checkout is not only supported, but recommended.

For example, if all of your ASF checkouts are in the same directory, you can
do something like the following:

```
:svn:
- /Users/rubys/svn/*
```
