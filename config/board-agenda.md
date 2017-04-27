Configuring the Board Agenda Tool

Install Dependencies
--------------------

Change directory to `whimsy/www/board/agenda`

Run:

```
$ bundle install
$ npm install
```

Look for a line that says either `Bundle complete!` or `Bundle updated!`.

Identify where files are to be found
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

Install poltergeist
-------------------

(optional, used by tests)

[poltergeist is now installed](https://github.com/teampoltergeist/poltergeist/tree/v1.13.0#installation) via `bundle install` from the Gemfile.

Verify using:

```
$ bundle install 
$ rake test
```

