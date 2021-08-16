#
# List of committees
#

_html do
  _base href: '..'
  _link rel: 'stylesheet', href: "stylesheets/app.css?#{cssmtime}"
  _whimsy_body(
    title: 'ASF PMC Listing',
    subtitle: 'List of all Top Level Projects',
    relatedtitle: 'More Useful Links',
    related: {
      "/committers/tools" => "Whimsy All Tools Listing",
      ASF::SVN.svnpath!('committers') => "Checkout the private 'committers' repo for Committers",
      "https://github.com/apache/whimsy/blob/master/www#{ENV['SCRIPT_NAME']}" => "See This Source Code",
      "mailto:dev@whimsical.apache.org?subject=[FEEDBACK] members/index idea" => "Email Feedback To dev@whimsical"
    },
    helpblock: -> {
      _p do
        _ 'A full list of Apache PMCs; click on the name for a detail page about that PMC. '
        _ 'You can also view (Member-private) '
        _a href: '/roster/nonpmc/' do
          _span.glyphicon.glyphicon_lock :aria_hidden, class: 'text-primary', aria_label: 'ASF Members Private'
          _ 'Non-PMC Committees (Brand, Legal, etc.)'
        end
        _ ' and '
        _a href: '/roster/group/' do
          _span.glyphicon.glyphicon_lock :aria_hidden, class: 'text-primary', aria_label: 'ASF Members Private'
          _ 'Other Groups of various kinds (from LDAP or auth).'
        end
      end
      _p do
        _ 'Chair names in BOLD below are also ASF Members.  Click on column names in table to sort; jump to A-Z project listings here:'
        _br
        "ABCDEFGHIJKLMNOPQRSTUVWXYZ".each_char do |c|
          _a c, href: "committee/##{c}"
        end
        _ '(note: the links only work properly if the page is sorted by project name ascending)'
      end
    },
    breadcrumbs: {
      roster: '.',
      committee: 'committee/'
    }
  ) do

    _table.table.table_hover do
      _thead do
        _tr do
          _th.sorting_asc 'Name', data_sort: 'string-ins'
          _th 'Chair(s)', data_sort: 'string'
          _th 'Established', data_sort: 'string'
          _th 'PMC Size', data_sort: 'int'
          _th 'Description', data_sort: 'string'
        end
      end
      _tbody do
        prev_letter=nil
        @committees.sort_by {|pmc| pmc.display_name.downcase}.each do |pmc|
          letter = pmc.display_name.upcase[0]
          if letter != prev_letter
            options = {id: letter}
          else
            options = {}
          end
          prev_letter = letter
          _tr_ options do
            _td do
              _a pmc.display_name, href: "committee/#{pmc.name}"
            end

            _td do
              pmc.chairs.each_with_index do |chair, index|
                _span ', ' unless index == 0

                if @members.include? chair[:id]
                  _b! {_a chair[:name], href: "committer/#{chair[:id]}"}
                else
                  _a chair[:name], href: "committer/#{chair[:id]}"
                end
              end
            end

            if not pmc.established
              _td ''
              _ td ''
              _td.issue 'Not in committee-info.txt'
            else
              if pmc.established =~ /^(\d\d)\/(\d{4})(.*)$/
                est = "#{$2}-#{$1}#{$3}"
              else
                est = pmc.established
              end
              _td est
              _td pmc.roster.size
              _td pmc.description
            end
          end
        end
      end
    end
  end
  _script %{
    $(".table").stupidtable();
  }
end
