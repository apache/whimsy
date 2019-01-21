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
show_all = (ENV['PATH_INFO'] == '/all')

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
          _ 'Every entry in bin/.archives should have up to 3 archive subscribers, except for the mail aliases, which are not lists.'
          _br
          _ 'Every mailing list should have an entry in bin/.archives'
          _br
          _ 'Unexpected/missing entries are flagged'
          _br
          _ 'Minotaur emails can be either aliases (tlp-list-archive@tlp.apache.org) or direct (apmail-tlp-list-archive@www.apache.org).'
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
        _th 'Archivers', data_sort: 'string'
      end
      ASF::MLIST.list_archivers do |dom, list, arcs|

        id = ASF::Mail.archivelistid(dom, list)

        ids[id] = 1 # TODO check for duplicates

        options = Hash.new # Any fields have warnings/errors?

        pubprv = binarchives[id]

        mino = arcs.select{|e| e[1] == :MINO}.map{|e| e[2]}.first
        if mino
          options[:mino]={class: 'info'} unless mino == 'alias'
        else
          mino = 'Missing'
          options[:mino]={class: 'warning'}
        end 
        
        mbox = arcs.select{|e| e[1] == :MBOX}.map{|e| e[2]}.first
        if mbox
          options[:mbox] = {class: 'danger'} if pubprv && mbox != pubprv  
        else
          mbox = 'Missing'
          options[:mbox] = {class: 'warning'}
        end

        pony = arcs.select{|e| e[1] == :PONY}.map{|e| e[2]}.first
        if pony
          options[:pony] = {class: 'danger'} if pubprv && pony != pubprv  
        else
          pony = 'Missing'
          options[:pony] = {class: 'warning'}
        end

          
        # must be done last
        unless pubprv
          pubprv = 'Not listed in bin/.archives'
          options[:pubprv] = {class: 'warning'} 
        end

        next unless show_all || options.keys.length > 0 # only show errors unless want all

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
