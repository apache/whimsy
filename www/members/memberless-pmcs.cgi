#!/usr/bin/ruby

#
# Provide a report on PMCs with a given number of ASF members
#

require 'whimsy/asf'
require 'wunderbar/bootstrap'
require 'wunderbar/jquery/stupidtable'
require 'date'

members = ASF::Member.list.keys
committees = ASF::Committee.load_committee_info

_html do
  count = (@count || 1).to_i

  if count == 1
    title = 'PMCs without any ASF members'
  else
    title = "PMCs without at least #{count} ASF members"
  end

  _title title

  _style %{
    img.logo {
      width: 160px;
      margin-left: 10px;
    }
  }

  # banner
  _a href: 'https://whimsy.apache.org/' do
    _img title: "ASF Logo", alt: "ASF Logo",
      src: "https://www.apache.org/img/asf_logo.png"
  end
  _img.logo src: '../../whimsy.svg'

  _h1_ title

  _table_.table.table_striped do
    _thead_ do
      _tr do
        _th 'PMC', data_sort: 'string-ins'
        _th 'Established', data_sort: 'string'
        _th 'Count', data_sort: 'int' if count > 1
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
        end
      end
    end
  end

  _script %{
    $(".table").stupidtable();
  }
end
