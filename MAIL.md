Notes on mail delivery
======================

Whimsy is subscribed to the members and board mailing lists, and is added to the secretary alias.

These emails are routed to the www-data mailbox by an aliases(5) file.

The www-data login has a procmailrc(5) file which checks the mail headers to route the mails to
one of the following:
- tools/deliver.rb: handles board and members mails (based on List-Id by default)
- www/secretary/workbench/deliver.rb: handles secretary mails

If the mail is not recognised, the default delivery is to the www-data mailbox
