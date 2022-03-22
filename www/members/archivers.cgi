#!/usr/bin/env ruby

PAGETITLE = "Archivers Subscription Crosscheck" # Wvisible:members
$LOAD_PATH.unshift '/srv/whimsy/lib'

require 'wunderbar'
require 'whimsy/asf'
require 'whimsy/asf/mlist'
require 'wunderbar/bootstrap'
require 'wunderbar/jquery/stupidtable'

show_all = (ENV['PATH_INFO'] == '/all') # all entries, regardless of error state
# default is to show entry if neither mail-archive nor markmail is present (mail-archive is missing from a lot of lists)
show_mailarchive = (ENV['PATH_INFO'] == '/mail-archive') # show entry if mail-archive is missing

# list of ids deliberately not archived
#                 INFRA-18129
NOT_ARCHIVED = %w{aceu19@apachecon.com temporaryconfluencetest@infra.apache.org bouncetest@infra.apache.org}

sublist_time = ASF::MLIST.list_time

def findarcs(arcs, type, arcleft)
  sel = arcs.select { |e| e[1] == type }
  addrs = sel.map { |e| e[0] }.uniq
  addrs.each { |addr| arcleft.delete(addr)}
  return [sel.map { |e| e[2] }.uniq.join, addrs]
end

def showdets(text)
  if text.kind_of? Array
    _ text[0]
    text[1].each do |t|
      _br
      _ t
    end
  else
    _ text
  end
end

# Fix relative links
if env['REQUEST_URI'] =~ %r{archivers(\.cgi)?/}
  href_pfx = '.'
else
  href_pfx = 'archivers'
end

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
          _ 'This script checks the list of archiver addresses that are subscribed to mailing lists'
          _br
          _ 'Every mailing list should have at least two archivers: MBOX and PONY'
          _br
          _ 'The MBOX and PONY archivers must agree on the the privacy setting'
          _br
          _ 'Unexpected/missing entries are flagged'
          _br
          _ 'Columns:'
          _ul do
            _li 'list - full list name'
            _li 'Private? - whether list is public or private, based on the MBOX archiver'
            _li 'MBOX - mbox-vm archiver'
            _li 'PONY - PonyMail (lists.apache.org) archiver'
            _li 'MAIL-ARCHIVE - @mail-archive.com archiver (public lists only)'
            _li 'MARKMAIL - markmail.org archiver (public lists only)'
            _li "Other Archivers - list of other archiver subscriptions (e.g. Whimsy) as at #{sublist_time}"
          end
          _ 'Showing: '
          if show_all or show_mailarchive
            _a 'issues (ignoring missing mail-archive subscriptions)', href: "#{href_pfx}/"
          else
            _b 'issues (ignoring missing mail-archive subscriptions)'
          end
          _ ' | '
          if show_mailarchive
            _b 'issues including missing mail-archive subscriptions'
          else
            _a 'issues including missing mail-archive subscriptions', href: "#{href_pfx}/mail-archive"
          end
          _ ' | '
          if show_all
            _b 'details for all lists'
          else
            _a 'details for all lists', href: "#{href_pfx}/all"
          end
        end
      }
    ) do

      _table.table do
        _thead_ do
          _tr do
            _th 'list', data_sort: 'string'
            _th 'Private?', data_sort: 'string'
            _th 'MBOX'
            _th 'PONY'
            _th 'MAIL-ARCHIVE'
            _th 'MARKMAIL'
            _th 'Other archivers', data_sort: 'string'
          end
        end
        _tbody do
          ASF::MLIST.list_archivers do |dom, list, arcs|
            # arcs = array of arrays, each of which is [archiver, archiver_type, "public"|"private"]

            lid = "#{list}@#{dom}"

            next if NOT_ARCHIVED.include? lid

            options = Hash.new # Any fields have warnings/errors?

            arcleft = arcs.map(&:first) # unused

            # in case there are multiple archivers with different classifications, we
            # join all the unique entries.
            # This is equivalent to first if there is only one, but will produce
            # a string such as 'privatepublic' if there are distinct entries
            # However it generates an empty string if there are no entries.

            mbox = findarcs(arcs, :MBOX, arcleft)

            pubprv = mbox[0] # get privacy setting from MBOX entry

            next if pubprv == 'restricted' # Don't show these

            if mbox[0].empty?
              mbox = 'Missing'
              options[:mbox] = {class: 'warning'}
            end

            pony = findarcs(arcs, :PONY, arcleft)
            if ! pony[0].empty?
              options[:pony] = {class: 'danger'} if pony[0] != pubprv
            else
              pony = 'Missing'
              options[:pony] = {class: 'warning'}
            end

            mail_archive = findarcs(arcs, :MAIL_ARCH, arcleft)
            if ! mail_archive[0].empty?
              options[:mail_archive] = {class: 'danger'} if mail_archive[0] != pubprv
            elsif pubprv == 'private'
              mail_archive = 'N/A'
            else
              mail_archive = 'Missing'
              options[:mail_archive] = {class: 'warning'}
            end

            markmail = findarcs(arcs, :MARKMAIL, arcleft)
            if ! markmail[0].empty?
              options[:markmail] = {class: 'danger'} if (markmail[0] != pubprv) || markmail[1].size > 1
            elsif pubprv == 'private'
              markmail = 'N/A'
            else
              markmail = 'Missing'
              options[:markmail] = {class: 'warning'}
            end

            options[:arcleft] = {class: 'warning'} if arcleft.size > 0

            if show_mailarchive
              needs_attention = options.keys.length > 0
            else # don't show missing mail-archive
              needs_attention = options.reject { |k, _v| k == :mail_archive && mail_archive == 'Missing' }.length > 0
            end
            next unless show_all || needs_attention # only show errors unless want all

            # This is not a warning per-se
            options[:pubprv] = {class: 'warning'} if pubprv == 'private'

            _tr do
              _td lid
              _td pubprv, options[:pubprv]
              _td options[:mbox] do showdets(mbox) end
              _td options[:pony] do showdets(pony) end
              _td options[:mail_archive] do showdets(mail_archive) end
              _td options[:markmail] do showdets(markmail) end
              _td arcleft.sort, options[:arcleft]
            end
          end
        end
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
