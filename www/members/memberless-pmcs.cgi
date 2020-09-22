#!/usr/bin/env ruby
PAGETITLE = "Crosscheck PMCs with few/no ASF Members" # Wvisible:members
$LOAD_PATH.unshift '/srv/whimsy/lib'
require 'whimsy/asf'
require 'wunderbar'
require 'wunderbar/bootstrap'
require 'wunderbar/jquery/stupidtable'
require 'date'
#
# Provide a report on PMCs with a given number of ASF members
#
counts = [1, 2, 3, 4]
_html do
  _body? do
    count = (@count || 3).to_i
    if count == 1
      subtitle = 'PMCs without any ASF members'
    else
      subtitle = "PMCs without at least #{count} ASF members"
    end
    _whimsy_body(
      title: PAGETITLE,
      subtitle: subtitle,
      related: {
        '/members/watch' => 'Potential Member Watch List',
        '/roster/committee/' => 'All PMC Rosters'
      },
      helpblock: -> {
        _p 'This displays PMC names where there are few/no ASF Members listed on the PMC.'
        _p do
          _ 'Switch to fewer than:'
          counts.each do |c|
            _a href: "/members/memberless-pmcs?count=#{c}" do
              _button.btn.btn_info c
            end
            _ " | " unless c.equal? counts.last
          end
          _ ' members on a PMC.'
        end
      }
    ) do
      members = ASF::Member.list.keys
      committees = ASF::Committee.load_committee_info
      _table_.table.table_striped do
        _thead_ do
          _tr do
            _th 'PMC', data_sort: 'string-ins'
            _th 'Established', data_sort: 'string'
            _th 'Count', data_sort: 'int' if count > 1
            _th 'Chair', data_sort: 'string'
          end
        end
        _tbody do
          committees.sort_by {|pmc| pmc.display_name.downcase}.each do |pmc|
            next if pmc.roster.keys.empty? # EA, Marketing, etc.
            next unless (pmc.roster.keys & members).length < count
            _tr_ do
              _td! do
                _a pmc.display_name, href: "../roster/committee/#{pmc.id}"
              end
              _td Date.parse(pmc.established).strftime('%Y/%m')
              _td (pmc.roster.keys & members).length if count > 1
              _td pmc.chair.cn
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

