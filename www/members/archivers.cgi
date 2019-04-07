#!/usr/bin/env ruby

PAGETITLE = "Archivers Subscription Crosscheck" # Wvisible:members
$LOAD_PATH.unshift '/srv/whimsy/lib'

require 'wunderbar'
require 'whimsy/asf'
require 'whimsy/asf/mlist'
require 'wunderbar/bootstrap'
require 'wunderbar/jquery/stupidtable'

ids={}
binarchives = ASF::Mail.lists(true)
binarchtime = ASF::Mail.list_mtime

show_all = (ENV['PATH_INFO'] == '/all') # all entries, regardless of error state
# default is to show entry if neither mail-archive nor markmail is present (mail-archive is missing from a lot of lists)
show_mailarchive = (ENV['PATH_INFO'] == '/mail-archive') # show entry if mail-archive is missing

# list of ids deliberately not archived
#                 INFRA-18129
NOT_ARCHIVED = %w{apachecon-aceu19}

sublist_time = ASF::MLIST.list_time

_html do
  _body? do
    _whimsy_body(
      title: PAGETITLE,
      related: {
        '/committers/moderationhelper' => 'Mail List Moderation Helper',
        'https://lists.apache.org' => 'Apache Ponymail List Archives',
      },
      helpblock: -> {
        _p! do
          _ 'This script compares bin/.archives with the list of archiver addresses that are subscribed to mailing lists'
          _br
          _ 'Every entry in bin/.archives should have up to 3 archive subscribers (5 for public lists), except for the mail aliases, which are not lists.'
          _br
          _ 'Every mailing list should have an entry in bin/.archives'
          _br
          _ 'Unexpected/missing entries are flagged'
          _br
          _ 'Minotaur emails can be either aliases (tlp-list-archive@tlp.apache.org) or direct (apmail-tlp-list-archive@www.apache.org).'
          _br
          _ 'Columns:'
          _ul do
            _li 'id - short id of list as used on mod_mbox'
            _li 'list - full list name'
            _li "Private? - public/private; derived from bin/.archives as at #{binarchtime}"
            _li 'MINO - minotaur archiver'
            _li 'MBOX - mbox-vm archiver'
            _li 'PONY - PonyMail (lists.apache.org) archiver'
            _li 'MAIL-ARCHIVE - @mail-archive.com archiver (public lists only)'
            _li 'MARKMAIL - markmail.org archiver (public lists only)'
            _li "Archivers - list of known archiver subscriptions as at #{sublist_time}"
          end
          _ 'Showing: '
          unless show_all or show_mailarchive
            _b 'issues excluding missing mail-archive subscriptions'
          else
            _a 'issues excluding missing mail-archive subscriptions', href: './'
          end
          _ ' | '
          if show_mailarchive
            _b 'issues including missing mail-archive subscriptions'
          else
            _a 'issues including missing mail-archive subscriptions', href: './mail-archive'
          end
          _ ' | '
          if show_all
            _b 'details for all lists'
          else
            _a 'details for all lists', href: './all'
          end
        end
      }
    ) do
      
    _table.table do
      _tr do
        _th 'id', data_sort: 'string'
        _th 'list', data_sort: 'string'
        _th 'Private?', data_sort: 'string'
        _th 'MINO'
        _th 'MBOX'
        _th 'PONY'
        _th 'MAIL-ARCHIVE'
        _th 'MARKMAIL'
        _th 'Archivers', data_sort: 'string'
      end
      ASF::MLIST.list_archivers do |dom, list, arcs|

        id = ASF::Mail.archivelistid(dom, list)

        next if NOT_ARCHIVED.include? id # skip error reports. TODO check if it is archived

        ids[id] = 1 # TODO check for duplicates

        options = Hash.new # Any fields have warnings/errors?

        pubprv = binarchives[id] # public/private

        # in case there are multiple archivers with different classifications, we
        # join all the unique entries. 
        # This is equivalent to first if there is only one, but will produce
        # a string such as 'privatepublic' if there are distinct entries
        # However it generates an empty string if there are no entries.

        mino = arcs.select{|e| e[1] == :MINO}.map{|e| e[2]}.uniq.join('')
        if ! mino.empty?
          options[:mino]={class: 'info'} unless mino == 'alias'
        else
          mino = 'Missing'
          options[:mino]={class: 'warning'}
        end 
        
        mbox = arcs.select{|e| e[1] == :MBOX}.map{|e| e[2]}.uniq.join('')
        if ! mbox.empty?
          options[:mbox] = {class: 'danger'} if pubprv && mbox != pubprv  
        else
          mbox = 'Missing'
          options[:mbox] = {class: 'warning'}
        end

        pony = arcs.select{|e| e[1] == :PONY}.map{|e| e[2]}.uniq.join('')
        if ! pony.empty?
          options[:pony] = {class: 'danger'} if pubprv && pony != pubprv  
        else
          pony = 'Missing'
          options[:pony] = {class: 'warning'}
        end

        mail_archive = arcs.select{|e| e[1] == :MAIL_ARCHIVE}.map{|e| e[2]}.uniq.join('')
        if ! mail_archive.empty?
          options[:mail_archive] = {class: 'danger'} if pubprv && mail_archive != pubprv  
        elsif pubprv == 'private'
          mail_archive = 'N/A'
        else
          mail_archive = 'Missing'
          options[:mail_archive] = {class: 'warning'}
        end
          
        markmail = arcs.select{|e| e[1] == :MARKMAIL}.map{|e| e[2]}.uniq.join('')
        if ! markmail.empty?
          options[:markmail] = {class: 'danger'} if pubprv && markmail != pubprv  
        elsif pubprv == 'private'
          markmail = 'N/A'
        else
          markmail = 'Missing'
          options[:markmail] = {class: 'warning'}
        end
              
        # must be done last as it changes pubprv
        unless pubprv
          pubprv = 'Not listed in bin/.archives'
          options[:pubprv] = {class: 'warning'} 
        end

        if show_mailarchive
          needs_attention = options.keys.length > 0
        else # don't show missing mail-archive
          needs_attention = options.reject{|k,v| k == :mail_archive && mail_archive == 'Missing'}.length > 0
        end
        next unless show_all || needs_attention # only show errors unless want all

        _tr do
          _td id
          _td! do
            _ list
            _ '@'
            _ dom
          end
          
          _td pubprv, options[:pubprv]
          _td mino, options[:mino]
          _td mbox, options[:mbox]
          _td pony, options[:pony]
          _td mail_archive, options[:mail_archive]
          _td markmail, options[:markmail]
          _td arcs.map{|e| e.first}.sort
        end
      end
    end

    missingids = binarchives.keys - ids.keys
    if missingids.length > 0
      _p.bg_warning do
        _ 'The following entries in bin/.archives do not appear to have an associated mailing list (probably they are aliases):'
        _br
        _ missingids
      end
    else
      _p 'All entries in bin/.archives correspond to a mailing list'
    end

    _script %{
      var table = $(".table").stupidtable();
      table.on("aftertablesort", function (event, data) {
        var th = $(this).find("th");
        th.find(".arrow").remove();
        var dir = $.fn.stupidtable.dir;
        var arrow = data.direction === dir.ASC ? "&uarr;" : "&darr;";
        th.eq(data.column).append('<span class="arrow">' + arrow +'</span>');
        });
      }
    end
  end
end
