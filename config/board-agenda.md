Configuring the Board Agenda Tool

You can run a local copy of the Board Agenda tool with the below config, 
for testing or training purposes.

See also:

- [https://whimsy.apache.org/board/test](https://whimsy.apache.org/board/test) - script showing environment
- [www/board/agenda/README.md](https://github.com/apache/whimsy/blob/master/www/board/agenda/README.md) - Detailed agenda walkthrough

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

If everything worked, you can run the agenda tool locally by:

```
rake test:server
```
