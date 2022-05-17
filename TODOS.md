# Whimsy Project TODOs

The Apache Whimsy project is maintained by volunteers, and includes both
the core server and ASF:: libraries, as well as many individual applications.
Patches are welcome - as is [reporting bugs](https://issues.apache.org/jira/browse/WHIMSY)
or [asking questions](https://lists.apache.org/list.html?dev@whimsical.apache.org).

This TODO :pencil: list is used by various committers for tasks, improvements,
and crazy ideas alike.  Comments appreciated.

## Core Improvements :round_pushpin:

- [ ] Share common code for places where we jump thru hoops or regexes
      to account for historical or file formats or odd PMC names.

    - [tools/collate_minutes.rb](tools/collate_minutes.rb) - maps PMC names displayed in board reports like concom
    - [lib/whimsy/asf/committee.rb](lib/whimsy/asf/committee.rb) - maps PMC names within Committee @@aliases
    - [lib/whimsy/asf/site.rb](lib/whimsy/asf/site.rb) - maps URLs for groups within Site @@default
    - [lib/whimsy/asf/mail.rb](lib/whimsy/asf/mail.rb) - maps mail list names within Committee.mail_list
    - [lib/whimsy/asf/podlings.rb](lib/whimsy/asf/podlings.rb) - maps mail list names within *_mail_list

- [ ] Improve code sharing between www/roster and www/board with lib/whimsy,
      as above regexes, and improving themes.rb use

- [ ] Higher level documentation of various lib/whimsy/asf modules, so that
      they and their associated output public/*.json files can be better
      used across whimsy and other tools.

## Crazy Ideas :tada:

- [ ] Create templates for new applications and normalize behaviors of
      existing applications to make a more consistent user experience.

## Done :checkered_flag:

- [x] Define core ASF style & header information in the model and
      implement in various applications.  [lib/whimsy/asf/themes.rb](lib/whimsy/asf/themes.rb)

- [x] Improve error handling in appropriate scripts to provide friendly
      user-visible cues on completion or stacktrace.  Best practice to use
      _body? in scripts and do complex operations inside that block:
      then wunderbar will emit header and formatted error message for user.

- [x] Implement custom server error messages. (done for /www browse and roster tool)

- [x] Show flow of data generated or consumed, tying back to the Role/Group that maintains it.
      [www/test/dataflow.cgi](https://whimsy.apache.org/test/dataflow.cgi)

- [x] Implement directory level index functionality to display a list
      of other available (and publishable) scripts there.
      Scan curdir; forall *.cgi where second line includes WVisible, display name/link.
      Using a positive comment ensures only scripts wishing to be displayed are visible.
      Effectively done as much is valuable: [www/committers/tools](https://whimsy.apache.org/committers/tools)
