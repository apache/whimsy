Monitoring
==========

The [current Whimsy server status](https://whimsy.apache.org/status/) is represented
as a tree of named nodes, and created by the [status monitoring code](https://github.com/apache/whimsy/tree/master/www/status/).

Nodes, names, and strings
-------------------------

Each major branch is produced by a [monitor](monitors).  Each monitor can
return a tree of nodes, or a single String, or an array of Strings.  The name
of the monitor is used as the name of the node produced.

Leaf nodes consist of a String, an array of Strings, or a Hash where one
element in the Hash has a key of `data` with a value of either a String or an
array of Strings.

Non-leaf nodes consist of a Hash where one element in the Hash has a key of
`data` with a value that is a Hash of names and child nodes.

Levels
------

Each node is associated with a status *level*.  Valid levels are `success`,
`info`, `warning`, `danger`, and `fatal`.  (The first four levels are modelled
after Bootstrap [alerts](http://getbootstrap.com/components/#alerts)).

Default level for valid leaf nodes is `success`.  Invalid leaf nodes (e.g., a
node consisting of a `nil` value) have a level of `danger`.  Only leaf nodes
that in the form of a Hash can have levels.  Leaf nodes that are not Hashes
will be normalized into a Hash with a `level` and `data`.

Default level for non-leaf nodes is the highest level in children nodes (where
`fatal` > `danger`, `danger` > `warning`, `warning` > `info` and `info` >
`success`).  Normally monitors will not assign level values for non-leaf
nodes.

Titles
------

Non-leaf nodes have a *title* describing the contents of the children.  Titles
show up as tooltips in the browser.

Default for title is either a list or a count of the names of child nodes with
the highest status.  Again, normally monitors will not assign title values for
nodes.

Text
----

Somewhat rare, but a node may have *text* which is used in place of the name
of the node for display purposes (the name continues to be used to produce the
anchor id for the element for linking purposes).

Internally, exceptions returned by a monitor are converted to a leaf node with
a name of `exception`, a title containing the exception, and data consisting
of a stack traceback. 

Href
----

Leaf nodes may have a *href* which will be used as the target for the link
used to display the contents of the leaf node (either a single String or an
array of Strings).

Mtime
-----

Anchors and the top of each major branch emanating from the root have an
*mtime* value which indicates when that data was last updated.  This is
described below in the control flow section below.

Leaf nodes can have a mtime value in place of data.  Such values will be
converted to local time and displayed as the last update value.  Hovering over
such items will show the GMT value of the time specified in ISO-8601 format.

Control Flow
============

Fetching the [status](https://whimsy.apache.org/status/) web page, which
can be done either by browsers or pings, results in a call to
[index.cgi](https://github.com/apache/whimsy/blob/master/www/status/index.cgi).
If it has been more than 60 seconds since the last status update, index.cgi
will call
[monitor.rb](https://github.com/apache/whimsy/blob/master/www/status/monitor.rb).
Monitor.rb will load and then call each of the monitors defined in the
[monitors](https://github.com/apache/whimsy/tree/master/www/status/monitors)
subdirectory.

Monitors are simple class methods.  Monitors can assume that they are called
no more often than once a minute, and are passed the normalized results of the
previous call.

As monitors are called in response to a ping, they are expected to produce
results in sub-second time in order to avoid the ping timing out.  (Monitors
are run in separate threads to minimize the total elapsed time).  Monitors
that perform activities that take a substantial amount of time may elect to do
so less frequently than once a minute, and can take advantage of the `mtime`
values to determine when to do so.

Results are collected into a hash, and that hash is then normalized.
Normalization resolves default values for items like levels and titles
recursively.

The normalized status is written to disk as [status.json](status.json), and
used as a response to pings that occur less than a minute after the previous
status.

Alerts
======

The Apache Software Foundation infrastructure team uses
[Nodeping](https://nodeping.com/reports/status/70MTNEPXE6) to monitor
status.  A dozen+ servers around the world check status regularly,
and will report failure results to the infrastructure
[Slack](https://the-asf.slack.com/) channel.  _Important:_ The Infrastructure
team ensures the underlying VM is up; the Whimsy PMC is responsible for 
the server software running inside the VM.

There are currently two Nodeping checks:
- Public facing: this checks the status return from the public URL https://whimsy.apache.org/incubator/podlings/by-age; this gives[Public check results](https://nodeping.com/reports/statusevents/check/2018042000290QH9Q-OZZ2KBZC)
- Full status: this checks the status return from https://whimsy.apache.org/status/; this gives [Status results](https://nodeping.com/reports/statusevents/check/2018042000290QH9Q-UMFGNACX)

While the full status for whimsy is represented as a tree of nodes, each
assigned one of our levels, and containing either child nodes or one or more
strings, all the infrastructure team is currently concerned with is a boolean
status (`success` and `info` are treated as success, and `warning` and
`danger` are treated as failure) and the computed title for the root node.
