ServiceWorkers preview
======================

TL;DR:
------

http://whimsy-test.apache.org/board/agenda/ enables [Service
Workers](https://developer.mozilla.org/en-US/docs/Web/API/Service_Worker_API)
on Chrome to (1) provide instant reload and (2) avoid hangs.  And to set the
stage for future totally offline operation.  This may also be basis for future
"toaster" style notifications of events like comments being posted or agenda
items being updated.

This is an early preview at this time.

Statement of the problem:
-------------------------

Some people like to use tabs.  This was fine with older versions of the board
agenda tool where every page was loaded from the server.  It is problematic
with the current board agenda tool where transitions between pages is
generally done without any server interaction.

Specifically, the problem is that updates made in one tab (adding a comment,
approving a report, adding minutes) need to be reflected in all tabs so that
the pages that show the queue of pending change and post-meeting actions are
constructed correctly.

Additionally, the current design has the server as the place where changes are
merged and sent back to the client.  This is done via [Server Sent
Events](https://developer.mozilla.org/en-US/docs/Web/API/Server-sent_events/Using_server-sent_events),
which requires a socket to be kept open.  Given that each browser limits the
number of open sockets per server to around six, having one socket open per
tab is limiting.

The current board agenda tool has code to share a socket and communicate data
received to all open tabs.  This code is fairly complex (prior to service
or shared workers there wasn't an architected ability to run a task "in the
background" and communicate results between tabs).  This code also seems to
have an undebugged leak of sockets, leading to cases where whimsy-vm3 is idle,
most users are unaffected, but one user sees whimsy as unresponsive.

FYI: as a workaround, change from whimsy.apache.org to whimsy3.apache.org or
even whimsy-vm3.apache.org.  These are all aliases for the same server, but
from a client perspective are completely different hosts.

Statement of the Solution:
--------------------------

Service Workers have a separate thread of execution from every tab and can
post messages to all tabs that are displaying a page in the scope of your
application.  They can also intercept requests to the server, and have caches.

The board agenda tool will start a service worker when it detects that it is
being run from whimsy-test.apache.org.  It will intercept load requests to any
agenda page and substitute a response of a blank page, leveraging the ability of
Vue.js to update pages dynamically.  It will then update that page twice:
once with a cache of the last known state of the agenda, and then a second
time with current data fetched from the server.

The service worker will also host the single socket receiving data from the
server.  This code is much streamlined as the code to communicate between tabs
can use
[Client.postMessage()](https://developer.mozilla.org/en-US/docs/Web/API/Client/postMessage)

Note: service workers may even continue for a period of time after
the last tab is closed, continuing to receive and process events from the
server.  This means that updates to caches may be made even when you aren't
viewing an agenda page.

CSS, JavaScript, and JSON files used by the application are also heavily
cached, so generally won't need to be reloaded when you open a new tab or
return to the agenda.

Usage:
------

Load the agenda page as you would normally, but use whimsy-test.apache.org has
the host.  The first time you visit this page it will behave just like it
always has.  Only after the page is completely loaded will it install a
service worker and prefetch some data.  This will complete in a few seconds.

Once this is complete, the next time you return to the agenda (or open an
agenda page in a new tab) loading should be all done via locally cached data.

Access to the board agenda application via other host aliases (e.g.
whimsy.apache.org or whimsy3.apache.org) is not affected by the installation
of a Service Worker.

Known Problems:
---------------

Service Workers are only supported on Firefox, Chrome, Opera, and Android at
this time.  It is under active development for Microsoft Edge.  There are no
known plans to support Service Workers in Safari.

Server Side Events are supported by all browsers but Internet Explorer and
Edge.  Unfortunately this function is not available to Service Workers in
Firefox (https://bugzilla.mozilla.org/show_bug.cgi?id=1267903).

This means that effectively Chrome (and perhaps Opera) are the only browsers
that can be used to support this function at this time.

Chrome has a problem when it encounters a page that is in cache, required
authentication to originally access it, and now is being fetched by a fresh
session in a Service Worker.  Service Workers don't have access to the DOM and
can't surface modal dialogs to prompt for authentication information.  The
symptom is that you get an authentication error.  If this happens, do a [force
reload](https://en.wikipedia.org/wiki/Wikipedia:Bypass_your_cache).

Firefox bug report: https://bugzilla.mozilla.org/show_bug.cgi?id=1291893

To date, I've yet to figure out how to effectively report this bug to Chrome.
See [twitter](https://twitter.com/samruby/status/758673369021710336),
[w3c](https://lists.w3.org/Archives/Public/public-webapps/2016JulSep/0016.html),
and
[blog](http://intertwingly.net/blog/2016/07/11/Service-Workers-First-Impressions).

On the plus side, this likely will be resolved as a part of the recent change
to the Fetch spec: https://github.com/whatwg/fetch/issues/70

This is an early preview, so there may be problems with sockets not restarting
after exiting and reloading.  The focus so far has been on the display of
the agenda, so fetching of other data (for example, queue of pending comments)
may not be initially loaded when you return to the page.  Any problems noted
should be easily be addressed - all the existing code from the board agenda
tool is in place, it is only the source of the events that has changed.

Problems?
---------

* [dev@whimsical.apache.org](mailto:dev@whimsical.apache.org)
* https://issues.apache.org/jira/browse/WHIMSY/
* https://github.com/apache/whimsy/issues

When all else fails
-------------------

Unregister your Service Worker using chrome://serviceworker-internals (for
firefox use about:serviceworkers)

Futures
-------

Possible future directions:

* [IndexedDB](https://developer.mozilla.org/en-US/docs/Web/API/IndexedDB_API)
  for offline storage
* Desktop application using [electron](http://electron.atom.io/)
* [Notifications](https://developer.mozilla.org/en-US/docs/Web/API/Notifications_API)
