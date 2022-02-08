Preface
---

 * I ask that you [give it five minutes](https://signalvnoise.com/posts/3124-give-it-five-minutes).
 * Be prepared to [rethink best practices](https://www.youtube.com/watch?v=x7cQ3mrcKaY).

The ASF manages its board meetings via a text file that contains the agenda
for the meeting.  PMC reports, comments on those reports, and action items
associated with those PMCs are stored in separate places in that text file.
The agenda tool brings this data together and makes it easier to both
navigate and update that file.

> I cannot stress enough how important this tool is. I was doing things the
> "old" way until recently. I was unaware of how far this tool had advanced. I
> now spend around 50% less time on board meeting prep than I used to before
> switching to this tool. I imagine secretary gets even more benefit than
> that. Multiply this across all directors and you have a tool of immense
> value.
>
> &mdash; Ross Gardler, ASF President

Preparation
---

This has been tested to work on Mac OSX and Linux.  It likely will not work
yet on Windows.

The easiest way to get started is with Docker (see below), but if you
prefer a more hands on approach read on.

For a partial installation, all you need is Ruby and Node.js.

For planning purposes, prereqs for a _full_ installation will require:

 * A SVN checkout of
  [board](https://svn.apache.org/repos/private/foundation/board).

 * A directory, preferably empty, for work files containing such things as
  uncommitted comments.

 * The following software installed:
     * Subversion
     * Ruby 1.9.3 or greater
     * Development libraries and tools (for native extensions)
         * MacOS users
             * Xcode command line tools (`sudo xcode-select --install`)
             * `brew install openldap`
             * `brew install cyrus-sasl`
         * Ubuntu users
             * `apt-get install ruby-dev`
             * `apt-get install libldap2-dev`
             * `apt-get install libsasl2-dev`
             * `apt-get install build-essential`
     * Node.js 14
     * [PhantomJS](http://phantomjs.org/) 2.0
         * Mac OS/X Yosemite users should either use `brew install phantomjs`
           or get the binary from comments on
           [12900](https://github.com/ariya/phantomjs/issues/12900).
         * Ubuntu users can get a working binary from the comments on
           [12948](https://github.com/ariya/phantomjs/issues/12948#issuecomment-78181293).

Note:

 * The installation of PhantomJS on Linux current requires a 30+ minute
   compile.  The binary provided for OS/X Yosemite is not part of the
   standard distribution for PhantomJS.  Feel free to skip this step on your
   first ("give it five minutes") pass through this.  If you see promise,
   come back and complete this step.

Kicking the tires
---

You have three choices Vagrant, Docker, or directly on your machine.

### Vagrant

Vagrant users can clone this repository and then run:

        vagrant up
        vagrant ssh -c "cd /vagrant && rake server:test"

Then visit [http://localhost:9292/](http://localhost:9292/)

### Docker

Docker users can get up and running by cloning this repository and
running the following two commands in that directory:

        docker build -t whimsy-agenda .
        docker run -p 9292:9292 -d whimsy-agenda

Now visit http://youdockerhost:9292

### Direct

After installing the above prerequisites run the following commands in a Terminal window:

    gem install bundler
    git clone https://github.com/rubys/whimsy-agenda.git
    cd whimsy-agenda
    npm install
    bundle install
    rake spec
    rake server:test

Visit [http://localhost:9292/](http://localhost:9292/) in your favorite browser.

Notes:

 * If you don't have PhantomJS installed, or have a version of PhantomJS
   prior to version 2.0 installed, one test will fail.

 * If you don't have io.js installed, two additional tests will fail.

 * The data you see is a sanitized version of actual agendas that have
   been included in the repository for test purposes.


Viewing Source (Live Results)
---

At this point, you have something up and running.  Let's take a look around.

 * The first thing I want you to do is use the view source function in your
   browser.  What you will see is:

     * A head section that pulls in some stylesheets.  Most notably, the
       stylesheet from [bootstrap](http://getbootstrap.com/).

     * a `<div>` element with an id of `main` followed by the HTML used
       to present the first page fetched from the server.  If you want to see
       a different page, go to that page and hit refresh then view source
       again.  This content is nicely indented and is fairly straightforward.

    * a few `<script>` elements that pull in vue, jquery, bootstrap, and
      the agenda app itself.  I suggest that you leave that for the moment,
      we'll come back to it.

    * an inline script that calls `new Vue` with a datastructure
      containing all the data the app needs on the client to do navigation.
      Most importantly, this page contains a parsed agenda.   Mentally file
      that away for later consideration.

 * Next I want you to find and launch your browser's JavaScript console.  In
   it, enter the following expression: `Main.item`.  If you are currently on
   the agenda page, the results will be underwhelming.  If so, go to another
   page, and try again.  You will see the data associated with the specific
   page you are looking at.  Instance variables will be preceded by an
   underscore.  Methods and computed properties will not be.

 * If you are so inclined, you can actually make changes to the
   datastructures.  Something to try: `Main.item._report = 'All is Good!'`

 * One last thing before we leave this section, go to an agenda page, and
   replace the final `/` in the URL with `.json`.  The contents you see is
   what is fetched by the client when it needs to get an update of the data.
   This data is heavily cached on both the client and server, so it takes
   negligible resources to check for updates.

Viewing Source (this time, Actual Code)
---

 * While you are unlikely to need to look at it, the agenda parsing logic
   is in [agenda.rb](https://github.com/apache/whimsy/blob/master/lib/whimsy/asf/agenda.rb)
   plus the [agenda](https://github.com/apache/whimsy/tree/master/lib/whimsy/asf/agenda)
   subdirectory.

 * the [views/pages/index.js.rb](views/pages/index.js.rb) file contains the
   code for the agenda page.  It defines a class with a `render` method.
   Names that start with an underscore become HTML elements.  Nesting is
   generally represented by `do`...`end` blocks, and occasionally (rarely) by
   curly braces.  Attributes are represented by `name: value` pairs.  Note the
   complete lack of `<%=` ... `%>` syntax required by things like JSP or erb.
   Iteration is done by naming what you want to iterate over, and following
   the `do` with a name in vertical bars that contains the instance.

   Element names that start with a capital letter are essentially macros.
   We'll come back to that.

 * the [views/pages/search.js.rb](views/pages/search.js.rb) file contains the
   code for the search page.  There are more methods defined here.  You will
   find definitions for these methods in the Vue
   [Lifecycle Methods](https://vuejs.org/v2/guide/instance.html#Lifecycle-Diagram).
   You will see logic mixed with presentation.  What makes this work
   is the component lifecycle that Vue provides.  Components have mutable
   state (which are the variables which are preceded by an `@` sign), and are
   passed immutable properties (variables preceded by two `@` signs).  Some
   methods are prohibited from mutating state (most notably: the `render`
   method).  Don't get hung up on the logic here, but do go to the navigation
   bar on the top right of the browser page, and select `Search` and play with
   search live.

   An item of special note: we are directly making use of the browser APIs for
   updating the
   [history](https://developer.mozilla.org/en-US/docs/Web/Guide/API/DOM/Manipulating_the_browser_history)
   of the window.

 * At this point, I suggest that you make a change.  More specifically, I
   suggest you break something.  Insert the keyword `do` into a random spot
   in either this or another file, and save your changes.  This will cause
   the server to restart.  Hit refresh in the browser, and you will see
   a stack traceback indicating where the problem is.  Undo this change,
   and then lets continue exploring.

 * The [views/forms/add-comment.js.rb](views/forms/add-comment.js.rb) file is
   probably a more typical example of a component.  The render function is
   more straightforward.  Not mentioned before, but element names followed by
   a dot followed by a name is a shorthand for specifying HTML class
   attributes.  And an element name followed by a dot followed by an
   exclamation point is shorthand for specifying HTML id attributes.  Both of
   these innovations were first pioneered by
   [markaby](http://markaby.github.io/).

   Of special interest in this file is the `onChange` and `onClick`
   attributes.  Both are examples of how you associate an event with a method.
   The `save` method will call post which will send data to the server,
   wait for the response, update pending based on that response, and then
   close the modal window.

   Finally, finding DOM elements is a common enough need that I've usurped
   the `~` operator to expand to the various ways to find a dom element
   based on a CSS selector (including `document.getElementById`,
   `document.getElementByClassName`, ...).  I've got an alternate
   implementation that maps such strings to jQuery calls.  I've gone back
   and forth, but for now I and am leaning towards the native implementation.

 * [views/actions/comment.json.rb](views/actions/comment.json.rb) is the code
   which is run on the server when you save a comment.  It gets a list of
   pending items for this user, modifies it based on the parameters passed,
   puts this data back and then returns the modified list to the client (this
   is the last line, in Ruby the keyword `return` is optional, and generally
   not used unless returning from the middle of a method).  Most server
   actions will be simple.  Some will do things like commit changes to svn.

 * I mentioned previously that element names that start with a capital
   letter are effectively macros.  You've seen `Index`, `Search`, and
   `AddComment` classes, each of which start with a capital letter.  These
   actually are examples of what Vue calls components that I have described
   as acting like macros.  `views/main.html.rb' contains the 'top'.
   [views/app.js.rb](views/app.js.rb) lists all of the files that make up the
   client side of the application.

 * This brings us back to to the `app.js` script mentioned much earlier.
   If you visit [http://localhost:9292/app.js](http://localhost:9292/app.js)
   you will see the full script.  Every bit of this JavaScript was generated
   from the js.rb files mentioned above.  Undoubtedly you have seen small
   amounts of JavaScript before but I suspect that much of this looks foreign.
   Nicely indented, commented, vaguely familiar, but still somewhat foreign.
   Many people these days generate JavaScript.  Popular with Vue is something
   called [JSX](http://facebook.github.io/react/docs/jsx-in-depth.html), but
   that's both controversial and [doesn't support if
   statements](http://facebook.github.io/react/tips/if-else-in-JSX.html).
   I make plenty of use of if statements (and more!) in my render methods.

   While you can bring the generated source up in your browser's JavaScript
   console, you don't have to.  Through the magic of
   [Source Maps](https://docs.google.com/document/d/1U1RGAehQwRypUTovF1KRlpiOFze0b-_2gc6fAH0KY0k/edit),
   you can view source and set breakpoints using the Ruby code that was
   used to generate this script.  The way this is done varies by browser.
   On Google Chrome, for example, Ctrl+Shift+J will bring up the JavaScript
   console.  Clicking on sources will show directories for buttons, elements,
   etc.

 * Layout of the page is done by three files:
   [views/layout/header.js.rb](views/layout/header.js.rb),
   [views/layout/main.js.rb](views/layout/main.js.rb), and
   [views/layout/footer.js.rb](views/layout/footer.js.rb).

 * Should you ever happen to look for the main routing functions, they
   are [routing.rb](routing.rb) on the server and
   [views/router.js.rb](views/router.js.rb) on the client.

Testing
---

If you've made it this far, you've undoubtedly spent more than the five
minutes I've asked of you.  Hopefully, that's because I've piqued your
interest.  Having a test suite is important as it will allow you to
confidently make changes without breaking things.  If you haven't yet,
I encourage you to install Poltergeist and io.js.

Before running the tests, run `rake clobber` to undo any changes you
make have made to the test data by running the application.

Now onto the tests:

  * [spec/parse_spec.rb](spec/parse_spec.rb) is a vanilla unit test that
    verifies that the output of a parse matches what you would expect.  This
    approach is good testing out server side logic.

  * [spec/index_spec.rb](spec/index_spec.rb),
    [spec/reports_spec.rb](spec/reports_spec.rb), and
    [spec/other_views_spec.rb](spec/other_views_spec.rb) use
    [capybara](https://github.com/jnicklas/capybara) to verify that the html
    produced matches what you would expect.  This makes use of the server side
    rendering of pages.  Generally this involves identifying things to look
    for in the HTML with CSS paths and either text or attribute values.
    Clearly this approach is focused on verifying HTML output.

  * [spec/forms_spec.rb](spec/forms_spec.rb) shows how client side logic
    (expressed in Ruby, but compiled to JavaScript) can be tested.  It does so
    by setting up a http server (the code for which is in
    [spec/vue_server.rb](spec/vue_server.rb)) which runs arbitrary scripts
    and returns the results as HTML.  This approach excels at testing a Vue
    component.

  * [spec/client_spec.rb](spec/client_spec.rb) takes this a bit further to
    do a client side unit test.  Instance variables set in tests are passed
    to the Vue server, and arbitrary JavaScript code can be executed using
    this data.  Output is in the form of XHTML-style tags which is then
    matched against CSS (or xpath) expressions.

  * For complete end to end testing,
    [spec/navigate_spec.rb](spec/navigate_spec.rb) actually tests
    functions with a real (albeit headless) webkit browser.  This test verifies
    that the back button actually works (verifying the browser `history`
    API calls were made correctly).

  * Finally, [actions_spec.rb](actions_spec.rb) verifies the server side logic
    executed in response to posting a comment.

Despite the diversity, the above tests have a lot of commonality and build
on standard Ruby test functions.  Together they should be able to cover
pretty much any type of testing requirements.

Running for real
---

So far, you've run with test data.  If you want to run for real, you need
to have a recent checkout of
https://svn.apache.org/repos/private/foundation/board and a directory to
store pending updates.  If you have both, create a file named `.whimsy`
in your home directory.  The file format is YAML, and here is mine:

    ---

    :svn:
    - /home/rubys/svn/foundation
    - /home/rubys/svn/committers
    - /home/rubys/svn/site/templates
    - /home/rubys/svn/apmail

    :lib:
    - /home/rubys/git/wunderbar/lib
    - /home/rubys/git/ruby2js/lib
    - /home/rubys/svn/whimsy/lib

    :ldap: ldaps://ldap1-us-east.apache.org:636

    :agenda_work: /home/rubys/tmp/agenda


Adapt as necessary.  You don't need to have all those entries in the `svn`
value to run the board agenda tool.  The `lib` value is is an array of
libraries that are to be used instead of gems you may have installed.  This is
useful if you are making changes to the agenda parsing logic, ruby2js or
wunderbar.  You can remove this too.  If you drop the `ldap` entry, one will
be picked randomly for you from the
[list of ASF LDAP servers](https://www.pingmybox.com/dashboard?location=304).

With this in place, start the server with `rake server` instead of
`rake server:test`.  It will tell you what directories are being watched
for changes - this list includes libraries listed in the `.whimsy` file.
It will also tell you what svn directory and agenda work directories are
being used.


Conclusion
---

Congratulations for making it this far.  To recap:

 * You have gotten the whimsy agenda application running locally on your
   own laptop or desktop.  You've seen how to inspect and interact with
   the running code, and explored a number of representative functions.

 * You've made a change and saw it deployed immediately (even though the
   change was to break things).

 * You've run the tests, so you can confidently make changes and know that
   they didn't break anything.

 * Most of all, you've seen that things seems unreasonably fast without
   you needing to expend much effort to make it so.

This code clearly isn't complete.  What I'm looking for is people who are
wlling to experiment and contribute.  Are you in?

Sketching out some ideas: adding a new page to the navigation dropdown
would involve:

  * Adding a `Link` to the navigation dropdown in
    [views/layout/header.js.rb](views/layout/header.js.rb)
  * Adding the path to the `route` method in
    [views/router.js.rb](views/router.js.rb)
  * Adding a Vue component for the page to `views/pages`
  * Adding any new files to [views/app.js.rb](views/app.js.rb)
  * Adding a specification to
    [specs/other_views_specs.rb](specs/other_views_specs.rb)

Adding a new modal dialog would involve:

  * Adding a entry to the buttons list in
    [views/models/agenda.rb](views/models/agenda.rb)
  * Adding a Vue component for the form to `views/forms`
  * Adding a server side action to `views/actions`.  A number of [actions
    from the current agenda
    tool](https://svn.apache.org/repos/infra/infrastructure/trunk/projects/whimsy/www/board/agenda/json)
    should be usable as is.
  * Adding any new files to [views/app.js.rb](views/app.js.rb)
  * Adding specifications to [specs/forms_specs.rb](specs/forms_specs.rb) and
    [specs/actions_specs.rb](specs/actions_specs.rb).


Gotchas
---

Nothing is perfect.  Here are a few things to watch out for:

 * On the server, Ruby code only has access to the standard Ruby libraries,
   which includes methods like `File.read` and `YAML.parse`.  On the client,
   Ruby code is translated to JavaScript which only has access to JavaScript
   libraries, which includes methods like `history.pushState` and
   `JSON.stringify`.  

   [Ruby2JS filters](https://github.com/rubys/ruby2js#filters) reduce this
   gap by converting many common Ruby methods calls to JavaScript equivalents
   (e.g., `a.include? b` becomes `a.indexOf(b) != -1`).  Currently the
   agenda tool makes use of the `vue`, `functions` and `require` filters.

 * In Ruby there isn't a difference between accessing attributes and methods
   which have no arguments.  In JavaScript there is.  To make this work,
   parenthesis are required when calling or defining methods that have
   no arguments.  Parenthesis are still optional when arguments are involved.

 * In Ruby, every method or block is expected to return something.  In
   JavaScript, many methods are expected to return nothing.  Ruby2JS knows
   enough to insert a `return` statement for property definitions (method
   definitions that don't have parenthesis), and the filters that are in place
   will insert `return` into blocks passes to `.map`, but in general if
   you want to return something from a function, you will need a `return`
   statement.  There is a `return` filter that will add more, but in general
   it seems easier to remember to add a `return` when you need it than to
   add return statements that return `null` or `unspecified`.

 * In Ruby, `$` is not a legal method name, so this common
   alias for `jQuery` isn't directly available.  jQuery isn't needed for
   vue, but is needed for Bootstrap.  As such there will be few places where
   this will be needed.  As previously mentioned, I've considered using
   the `~` operator for this.

If you encounter any other gotchas, let me know and I'll update this README.

Further reading:
---

 * [bootstrap](http://getbootstrap.com/) - the most popular HTML, CSS, and JS
   framework for developing responsive, mobile first projects on the web
 * [capybara](https://github.com/jnicklas/capybara#readme) - helps you test
   web applications by simulating how a real user would interact with your app
 * [vue](https://vuejs.org/) - a JavaScript library for
   building user interfaces
 * [ruby2js](https://github.com/rubys/ruby2jw/#readme) - minimal yet
   extensible Ruby to JavaScript conversion.
 * [phantomjs](http://phantomjs.org/) -  a headless WebKit scriptable with a
   JavaScript API
 * [sinatra](http://www.sinatrarb.com/) - a
   [DSL](http://en.wikipedia.org/wiki/Domain-specific_language) for quickly
   creating web
   applications in Ruby with minimal effort
 * [wunderbar](https://github.com/rubys/wunderbar/#readme) - easy HTML5
   applications
