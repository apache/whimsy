Preparation
---

This has been tested to work on Mac OSX and Linux.  It may not work yet on
Windows.

For a partial installation, all you need is Ruby and Node.js.

For planning purposes, prereqs for a _full_ installation will require:

 * A SVN checkout of
  [board](https://svn.apache.org/repos/private/foundation/board).

 * A directory, preferably empty, for work files containing such things as
  uncommitted comments.

 * The following software installed:
     * Subversion
     * Ruby 1.9.3 or greater
     * Node.js
     * PhantomJS 2.0
         * Mac OS/X Yosemite users may need to get the binary from comments
           on [12900](https://github.com/ariya/phantomjs/issues/12900).

Kicking the tires:
---

```
sudo gem install bundler
git clone ...
cd ...
bundle install
rake
RACK_ENV=test puma
```

Visit http://localhost:9292/ in your favorite browser.

Notes:

 * If you don't have PhantomJS installed, or have a version of PhantomJS
   prior to version 2.0 installed, one test will fail. 

 * The data you see is a sanitized version of actual agendas that have
   been included in the repository for test purposes.


