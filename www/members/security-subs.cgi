#!/usr/bin/env ruby
$LOAD_PATH.unshift File.realpath(File.expand_path('../../../lib', __FILE__))
require 'wunderbar/bootstrap'
require 'whimsy/asf'
require 'whimsy/asf/mlist'

# ensure that there is a trailing slash (so relative paths will work)
if not ENV['PATH_INFO']
  print "Status: 302 Found\r\nLocation: #{ENV['SCRIPT_URI']}/\r\n\r\n"
  exit
end

# extract information for all security@pmc.apache.org lists
lists = {}
ASF::MLIST.list_parse('sub') do |dom, list, subs|
  next unless list == 'security'
  next unless dom.end_with? '.apache.org'
  lists[dom.sub('.apache.org', '')] = subs
end

_html do
  path = ENV['PATH_INFO'].sub('/', '')
  if path == ''
    _whimsy_body(
      title: "Security Mailing List Subscriptions"
    ) do
      _ul.list_group do
	lists.each do |dom, subs|
	  _li.list_group_item do
	    _a dom, href: dom
	  end
	end
      end
    end

  elsif lists[path]
    committee = ASF::Committee.find('whimsy')

    _whimsy_body(
      title: "Security Mailing List Subscriptions: #{path}"
    ) do

      _table.table do
	_thead do
	  _tr do
	    _th 'email'
	    _th 'person'
	  end
	end

	_tbody do
	  lists[path].sort_by {|email| email.downcase}.each do |email|
	    person = ASF::Person.find_by_email(email)
	    if person
	      if person.asf_member? or committee.committers.include? person
		color = 'bg-success'
	      else
		color = 'bg-warning'
	      end
	    else
	      color = 'bg-danger'
	    end

	    _tr class: color do
	       _td email
	       if person
		 if person.asf_member?
		   _td do
		     _b do
		       _a person.public_name, 
			 href: "../../roster/committer/#{person.id}"
		     end
		   end
		 else
		   _td do
		     _a person.public_name, 
		       href: "../../roster/committer/#{person.id}"
		    end
		 end
	       else
		 _td
	       end
	    end
	  end
	end
      end
    end

  else
    print "Status: 404 Not Found\r\n\r\n"
  end
end
