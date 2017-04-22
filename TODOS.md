# Whimsy Project TODOs

The Apache Whimsy project is maintained by volunteers, and includes both 
the core server and ASF:: libraries, as well as many individual applications.
Patches are welcome - as is [reporting bugs](issues.apache.org/jira/browse/WHIMSY) or [asking questions](https://lists.apache.org/list.html?dev@whimsical.apache.org).

This TODO :pencil: list is used by various committers for tasks, improvements,
and crazy ideas alike.  Comments appreciated.

## Core Improvements :round_pushpin:

- [ ] Define core ASF style & header information in the model and 
      implement in various applications.  [WHIMSY-81](https://issues.apache.org/jira/browse/WHIMSY-81)

- [ ] Improve error handling in appropriate scripts to provide friendly
      user-visible cues on completion or stacktrace.  [On Mailing List](https://lists.apache.org/thread.html/a6743ba8e0132f865e2f43ea5eded30ad2bc81aeb2445973b8f89087@%3Cdev.whimsical.apache.org%3E)

- [ ] Implement custom server error messages.

- [ ] Share common code for places where we jump thru hoops or regexes
      to account for historical or file formats or odd PMC names.
      
      - foundation/board/scripts/collate_minutes.rb
      - lib/whimsy/asf/committee.rb
      - lib/whimsy/asf/site.rb

## Crazy Ideas :tada:

- [ ] Create templates for new applications and normalize behaviors of 
      existing applications to make a more consistent user experience.
      
- [ ] Implement directory level index functionality to display a list 
      of other available (and publishable) scripts there. 
      Scan curdir; forall *.cgi where second line includes WVisible, display name/link.
      Using a positive comment ensures only scripts wishing to be displayed are visible.



