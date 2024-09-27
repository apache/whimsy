Notes on cutover
================

Some notes on performing a cutover, e.g. for upgrading a host system.

Pre-requisites
==============
The target system must be up and running. Check the following:
- /srv/whimsy/www/maintenance.txt is present (this stops most access)
- all cronjobs are running OK
- system is receiving mail, and can send emails
- the name whimsy.apache.org is included in the website certificate
- can access the host using https:
- during cutover, update access has to be disabled for the agenda and secretary workbench,
so try to select a cutover date that is a less busy time (ask board@)
- a suitable time has been arranged with Infra for the DNS update.
- /srv/whimsy/notice.txt has been created to give notice of the changeover time
- an initial rsync of local data has been performed (this will save time later)

Suggested process
=================
- double-check that Infra will be available at around the desired time
- About 1 hour before changeover, send an email to board@ and secretary@ confirming the changeover time.
- About 20 mins before, touch /srv/whimsy/migrating.txt. This will disable writes by users of agenda and workbench. It should be reflected in the workbench header (not yet done for agenda)
- refresh the local data copy on the target system. This should pick up very few new files (mainly the secretary mail YAML files), as incoming emails should be being stored by both systems.
If there are unexpected discrepancies, the cause must be determined before cutover.
- Remove /srv/whimsy/www/maintenance.txt on the target system. The workbench should accessible on the target host, and should show a message that it is not the active node for changes.
- The system is now ready for changeover
- Contact Infra to get DNS changed over. This should only take a few minutes. 
- Once DNS has been updated (can check with ping), 
- Touch /srv/whimsy/www/maintenance.txt on the source system to prevent further updates


Old system tidyup
=================
- disable cronjobs. Remove the cronjob class reference from the old Puppet node definition. Once the change has been applied, use root to delete the crontabs:
  - sudo crontab -u www-data -r
  - sudo crontab -u whimsysvn -r
- update listmodsubs.sh and whimsy_qmail_ids.sh in Puppet to stop pushing mail data to the old host
- login to the mail gateway and remove the old host subscriptions using ~apmail/bin/whimsy_subscribe.sh. Note that the script generates commands that should be reviewed and then applied.

When the old system is finally decommissioned, remove the Puppet definitions
