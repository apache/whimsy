Whimsy runs atop a variety of software and configuration dependencies.
This document is merely an overview, and is not necessarily complete.

## Software Dependencies

- Apache HTTP Web Server 2.x
- Ruby 1.9.x
- Rack
- Phusion Passenger
- Puppet (for our production deployment)

A variety of Ruby gems:

Wunderbar - HTML Generator and CGI application support
Source: https://github.com/rubys/wunderbar
Gem: wunderbar
Module: wunderbar

Ruby-ldap - LDAP for Ruby
Source: https://github.com/bearded/ruby-ldap
Gem: ruby-ldap
Module: ldap

nokogiri - HTML parser for Ruby

Other Ruby gems as in `asf.gemspec`.
