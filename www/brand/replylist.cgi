#!/usr/bin/env ruby
PAGETITLE = "DEMO: proposed UI for mailing list view for reply features"
$LOAD_PATH.unshift '/srv/whimsy/lib'
require 'whimsy/asf'
require 'wunderbar'
require 'wunderbar/bootstrap'
require 'wunderbar/jquery'

_html do
  _body? do
    _whimsy_body(
      title: PAGETITLE,
      related: {
        "https://www.apache.org/foundation/marks/resources" => "Trademark Site Map",
        ASF::SVN.svnpath!('foundation', 'Brand', 'runbook.txt') => "Members-only Trademark runbook",
        "https://lists.apache.org/list.html?trademarks@apache.org" => "Ponymail interface to trademarks@"
      },
      helpblock: -> {
        _p do
          _ 'This is a wireframe '
          _strong 'DEMO'
          _ ' of a proposed tool to allow ASF Members to review incoming questions on a private mailing list, and then select a '
          _em 'boilerplate reply'
          _ ' to send to an original questioner. See '
          _a 'Proposed how to reply guide', href: ASF::SVN.svnpath!('foundation', 'Brand', 'replies-readme.md')
        end
        _p do
          _ 'This list would display the last 30 (or so) days of messages on a private list, and have UI that shows info about the messages, plus action buttons to create a reply, see: '
          _a 'DEMO reply form to edit/send', href: '/brand/replyui.cgi'
        end
      }
    ) do
      _h3 'DEMO: wireframe of maillist display', id: 'listheader'

      _table.table.table_hover.table_striped do
        _thead_ do
          _tr do
            _th 'Expand', data_sort: 'string'
            _th 'Who', data_sort: 'string'
            _th 'Subject', data_sort: 'string'
            _th 'Date', data_sort: 'string'
            _th 'Reply', data_sort: 'string'
            _th 'Flags', data_sort: 'string'
          end
        end
        _tbody do
          _tr_ do
            _td do
              _span.glyphicon.glyphicon_expand :aria_hidden
            end
            _td 'Jane Doe'
            _td 'Help! I want to abuse Apache Foo brand!'
            _td '2017-12-12'
            _td do
               _a 'Reply', href: '#', onclick: "alert('This would popup UI to choose a boilerplate reply.');"
               _ ' | '
               _a 'Mark', href: '#', onclick: "alert('This might allow marking for attention, as spam, or other workflow.');"
               _ ' | '
               _a 'Read', href: '#', onclick: "alert('This or the expand button in leftmost column would open the mail for reading.');"
            end
            _td do
              _a '(flag1)', href: '#', onclick: "alert('This could display flags or marks, or other workflow about this email.');"
            end
          end
          _tr_ do
            _td do
              _span.glyphicon.glyphicon_collapse_down :aria_hidden
            end
            _td 'Jack Doe'
            _td 'Question about event usage'
            _td '2017-12-13'
            _td do
              _span.em 'Collapse'
            end
            _td do
              _a '(flag2)', href: '#', onclick: "alert('This could display marks or flags, or other workflow about this email.');"
            end
          end
          _tr_ do
            _td colspan: 4 do
              _p 'This would be the body of the /Question about event usage/ email above, perhaps?'
              _p do
                _ 'I.e. the list view should let a Member quickly:'
                _ul do
                  _li 'Read thru recent incoming emails that might need replies'
                  _li 'See which incoming emails already have replies/are answered/are otherwise marked'
                  _li 'Quickly open one of the emails to read it, to see if they want to try replying'
                  _li 'Click a button to select a boilerplate reply and then edit it.'
                end
              end
            end
            _td.strong 'Reply | Mark'
          end
          _tr_ do
            _td do
              _span.glyphicon.glyphicon_expand :aria_hidden
            end
            _td 'Ruby Sammy'
            _td '[MERCH] Luxury gems using Apache feather'
            _td '2017-12-24'
            _td do
               _a 'Reply', href: '/brand/replyui.cgi'
               _ ' | '
               _a 'Mark', href: '#', onclick: "alert('This might allow marking for attention, as spam, or other workflow.');"
               _ ' | '
               _a 'Read', href: '#', onclick: "alert('This or the expand button in leftmost column would open the mail for reading.');"
            end
            _td ' '
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
