#!/usr/bin/env ruby
PAGETITLE = "Apache Mailing List Info" # Wvisible:members mail
$LOAD_PATH.unshift '/srv/whimsy/lib'

# parse mailing list flags and try to interpret them

require 'wunderbar'
require 'whimsy/asf'
require 'whimsy/asf/mlist'
require 'wunderbar/bootstrap'
require 'wunderbar/jquery/stupidtable'

FLAGS = %{
-m message moderation (see also -u)
-u user posts (i.e. subscribed or allowed)

-mu allow subscribers to post, moderate all others (submod)
-mU moderate all posts (modall)
-Mu allow subscribers to post, reject all others (subonly)
-MU allow anyone to post (open)

-mz reject if it is not from an apache.org address, then moderate
-Mz reject if sender is not an apache.org address or in LDAP

-s subscriptions are moderated (usually means the list is private)

-x check mime-type, size etc
-y send copy to security@apache.org
-z sender/from address checking: see above
}
#  announce@a.o: mUxYz

def type(mu)
  {
    mu: 'submod',
    mU: 'modall',
    Mu: 'subonly',
    MU: 'open',
  }[mu.to_sym]
end

query = ENV['QUERY_STRING'] || ''
params = CGI.parse(query)
filter = nil
# Only allow letters in the query string so it is safe to use
if params['filter'].last =~ %r{^([a-zA-Z]+)$}
  # Convert xmU into m.......U..x
  sorted = $1.split('').sort_by(&:upcase)
  letters = []
  letters << sorted[0,1] # first letter needed to start off
  sorted.each_cons(2).with_index do |(a, b), i|
    gap = (b.upcase.ord - a.upcase.ord - 1)
    if gap > 0
      gap.times {letters << '.'}
    else
      raise ArgumentError,"Repeated letters #{[a, b]} not allowed"
    end
    letters << b
  end
  filter = Regexp.new(letters.join)
end

listfilter = params['match'].last

mod_counts = ASF::MLIST.list_moderators(nil).first.map {|x,y| [x, y.length]}.to_h

list_types = {}
ASF::MLIST.list_types(true) {|d,l,t| list_types["#{l}@#{d}"] = t}

_html do
  _body? do
    _whimsy_body(
      title: PAGETITLE,
      related: {
        'https://svn.apache.org/repos/infra/infrastructure/apmail/trunk/bin/EZMLM_FLAGS.txt' =>
          'Description of all flags',
        'https://svn.apache.org/repos/infra/infrastructure/apmail/trunk/.ezmlmrc' =>
          '.ezmlmrc file which interprets the flags',
        'http://untroubled.org/ezmlm/man/man1/ezmlm-make.1.html' => 'ezmlm-make(1)',
        'https://svn.apache.org/repos/infra/infrastructure/apmail/trunk/bin/makelist-apache.sh' =>
          'makelist-apache.sh - script tp create an ASF list; sets up options for ezmlm-make(1)',
        'https://svn.apache.org/repos/infra/infrastructure/apmail/trunk/bin' =>
          'Location of tools',
        },
      helpblock: -> {
        _h2 'DRAFT - treat information with caution'
        _p do
          _ "This script shows the flag settings for all mailing lists, and attempts to interpret them."
        end
        _p %{
          'mod count' is the number of moderators for the list.
          Lists should ideally have at least 3 moderators to ensure timely responses.
          The count is enclosed in [] if the list is 'open' or 'subonly' (and not private(s)),
          because posts (and subscriptions) don't need to be moderated in that case.
        }
        _p %{
          Note that there are other settings which affect the behaviour, and the initial behaviour defined
          by the flags can be modified by local changes to the editor script.
        }
        _p do
          _ 'The following query attributes can be added to the URL to filter the output:'
          _dl do
            _dt 'match'
            _dd 'Regex match against the full list name, e.g. dev@ or @apache\.'
            _dt 'filter'
            _dd 'Filter flags; must only contain characters A-Za-z, checks if the provided letters are in flags'
          end
          _ 'For example:'
          _pre '?filter=S&match=private@'
          _ 'This should not produce any output as private@ lists should require subscription moderation (s)'
          
        end
        _ 'Sample flag meanings'
        _pre FLAGS
      }
    ) do

      _table.table.table_striped do
        _thead_ do
          _tr do
            _th 'list', data_sort: 'string'
            _th 'domain', data_sort: 'string'
            _th "flags #{filter}", data_sort: 'string'
            _th 'Type (mu)', data_sort: 'string'
            _th 'mod count', data_sort: 'int'
            _th 'Known (z)', data_sort: 'string'
            _th 'Moderate subs(s)', data_sort: 'string'
            _th 'Archiver type', data_sort: 'string'
            _th 'Filter (x)', data_sort: 'string'
            _th 'cc.Security (y)', data_sort: 'string'
          end
        end
        _tbody do
          ASF::Mail.parse_flags(filter) do |domain, list, flags|
            lad = "#{list}@#{domain}"
            next if listfilter and ! lad.include? listfilter
            mu = flags.tr('^muMU', '')
            _tr do
              _td data_sort_value: "#{list}-#{domain}" do
                _a list, href: "https://lists.apache.org/list.html?#{lad}", target: '_blank'
              end
              _td data_sort_value: "#{domain}-#{list}" do
                _a domain, href: "https://lists.apache.org/list.html?#{lad}", target: '_blank'
              end
              _td flags
              _td do
                _ mu
                _ type(mu)
              end
              count = mod_counts[lad]
              if !flags.include?('s') and %w{subonly open}.include? type(mu)
                # ensure unmoderated lists are not penalised for having few moderators
                _td data_sort_value: count+100 do
                  _ "[#{count}]"
                end
              else
                if count.to_i < 3
                  _td class: 'bg-danger' do
                    _ count
                  end
                else
                  _td count
                end
              end
              _td flags.include? 'z'
              _td flags.include? 's'
              _td list_types[lad]
              _td flags.include? 'x'
              _td flags.include? 'y'
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
