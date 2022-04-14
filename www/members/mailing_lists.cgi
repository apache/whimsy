#!/usr/bin/env ruby
PAGETITLE = "Apache Mailing List Info" # Wvisible:members
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

-mz moderate after checking sender is known
-Mz unmoderated, but requires sender to be known

-s subscriptions are moderated (i.e. private list)

-x check mime-type, size etc
-y send copy to security@apache.org
-z check that sender address is known (i.e. @apache.org or in LDAP)
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

query = ENV['QUERY_STRING']
# Only allow letters in the query string so it is safe to use
if query =~ %r{^filter=([a-zA-Z]+)$}
  # Convert xmU into m.......U..x
  letters = []
  $1.split('').sort_by(&:upcase).each_cons(2).with_index do |(a, b), i|
    letters << a if i == 0
    (b.upcase.ord - a.upcase.ord - 1).times {letters << '.'}
    letters << b
  end
  filter = Regexp.new(letters.join)
else
  filter = nil
end

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
          Note that there are other settings which affect the behaviour, and the initial behaviour defined
          by the flags can be modified by local changes to the editor script.
        }
        _ 'Sample flag meanings'
        _pre FLAGS
      }
    ) do

      _table.table.table_striped do
        _thead_ do
          _tr do
            _th 'list', data_sort: 'string'
            _th "flags #{filter}", data_sort: 'string'
            _th 'Type (mu)', data_sort: 'string'
            _th 'Known (z)', data_sort: 'string'
            _th 'Private (s)', data_sort: 'string'
            _th 'Filter (x)', data_sort: 'string'
            _th 'cc.Security (y)', data_sort: 'string'
          end
        end
        _tbody do
          ASF::Mail.parse_flags(filter) do |domain, list, flags|
            mu = flags.tr('^muMU', '')
            _tr do
              _td data_sort_value: "#{domain}-#{list}" do
                _a "#{list}@#{domain}", href: "https://lists.apache.org/list.html?#{list}@#{domain}", target: '_blank'
              end
              _td flags
              _td do
                _ mu
                _ type(mu)
              end
              _td flags.include? 'z'
              _td flags.include? 's'
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
