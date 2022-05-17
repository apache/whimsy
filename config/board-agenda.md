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

Debugging
---------

The server is a straightforward Sinatra/Rack application.  Most of the logic
can be found in [routes.rb](../routes.rb), [models/](../models/), and
[views/actions/](../views/actions/).  Parsing the agenda itself is done in
[agenda.rb](../lib/whimsy/asf/agenda.rb) and
[agenda/](../lib/whimsy/asf/agenda/).

The server provides the client with data in JSON format.  Most importantly, a
parsed agenda can be seen by going to the agenda page for a given month and
replacing the trailing `/` with `.json`.

The client itself is JavaScript and is produced by converting the files in the
[view](../view) directory *except* for the `actions` subdirectory from Ruby to
JavaScript using [ruby2js](https://github.com/rubys/ruby2js).  The generated
JavaScript makes heavy use of [Vue.js](https://vuejs.org/).

You shouldn't need to look at the generated JavaScript much, but if you wish
to, it can be found in [app.js](https://whimsy.apache.org/board/agenda/app.js).
This file makes use of modern JavaScript features like `let` and `class`.
Older browsers (and first time you visit a page with a new browser) will be
provided with [app-es5.js](https://whimsy.apache.org/board/agenda/app-es5.js)
instead.

Vue.js builds up a "virtual DOM" in response to calls to `$h`, each of which
creates a single element.  The translation from
[wunderbar](https://github.com/rubys/wunderbar) style syntax to executable code
is done by ruby2js.

On the client, the browser can be used as an IDE.  In Chrome, you can click on
the `⋮` icon, select `More Tools` then `Developer Tools` to access the IDE.  If
you click on the sources tab, you can navigate from `whimsy.apache.org` to
`board/agenda` to the original source of the function you wish to debug.  A
[sourcemap](https://docs.google.com/document/d/1U1RGAehQwRypUTovF1KRlpiOFze0b-_2gc6fAH0KY0k/edit)
is provided to the browser so that it understands the mapping.

You can set breakpoints in the code, and use the `console` tab to evaluate
expressions and execute statements.  If you are viewing a specific page, you
can view the object associated with that page by evaluating `Main.item`.

Even though the source you are viewing is in Ruby, the console only understands
JavaScript expressions.  Mostly, this doesn't matter much as the variables
names are preserved in the translation, but does make a difference if you want
to call builtin functions.

More information can be found in the
[board/agenda/README](../www/board/agenda/README.md).
