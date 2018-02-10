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

Install chrome and chromedriver
-------------------

(optional, used by tests)

Install [Chrome](https://www.google.com/chrome/).

Install chromedriver:

```
brew install chromedriver
```

Verify using:

```
$ chromedriver -v
ChromeDriver 2.35.528157 (4429ca2590d6988c0745c24c8858745aaaec01ef)
```

