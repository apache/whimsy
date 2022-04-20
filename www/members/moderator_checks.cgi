#!/usr/bin/env ruby
PAGETITLE = "Apache List Moderator checks" # Wvisible:members
$LOAD_PATH.unshift '/srv/whimsy/lib'

# check moderators are known

require 'wunderbar'
require 'whimsy/asf'
require 'whimsy/asf/mlist'
require 'wunderbar/bootstrap'
require 'wunderbar/jquery/stupidtable'

MODERATORS = %w{
  mod-private@gsuite.cloud.apache.org
  mod-board@gsuite.cloud.apache.org
  secretary@apache.org
  board-chair@apache.org
}

def private_mod(lid, mod)
  dom = lid.split('@')[-1]
  ["pmc@#{dom}", "private@#{dom}"].include? mod
end

_html do
  _body? do
    _whimsy_body(
      title: PAGETITLE,
      related: {
        },
      helpblock: -> {
        _h2 'DRAFT - List moderators whose email addresses are not recognised'
        _p 'If the domain is @apache.org, the email is most likely a typo'
        _p 'In other cases, perhaps the email is not registered'
        _p do
          _b 'Emails are matched exactly - case is treated significant, even for domains'
        end
      }
    ) do
      lists, _time = ASF::MLIST.list_moderators(nil)
      emails = ASF::Mail.list
      unknown = Hash.new { |h, k| h[k] = []}
      lists.each do |lid, mods|
        mods.each do |mod|
          unknown[mod] << lid unless MODERATORS.include? mod or emails[mod] or private_mod(lid, mod)
        end
      end

      _table.table.table_striped do
        _thead_ do
          _tr do
            _th 'Unknown email addresses', data_sort: 'string'
            _th 'Lists moderated', data_sort: 'string'
          end
        end
        _tbody do
          unknown.sort_by {|x, y| p = x.split('@'); [p[1], p[0]]}.each do |email, lids|
            _tr do
              _td email
              _td lids.join(',')
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
