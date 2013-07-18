#!/usr/bin/ruby1.9.1
require 'wunderbar'

_html do
  _head do
    _title 'Color legend'
    _style %{
      .missing    {background-color: #F55}
      .ready4me   {background-color: #F20}
      .ready-me   {background-color: #0FE}
      .ready      {background-color: #F90}
      .reviewed   {background-color: #9F9}
      .commented  {background-color: #FF0}
    }
  end

  _body do
    _h2 'Color codes'

    _table do
      _tbody do
        _tr.missing do
          _td 'Report not present'
        end
        _tr.ready do
          _td "Needs to be covered in the meeting (either not enough preapprovals or not subject to preappovals)"
        end
        _tr class: 'ready4me' do
          _td "Report doesn't have enough preapprovals and the Director viewing this page hasn't reviewed it"
        end
        _tr class: 'ready-me' do
          _td "Report approved with no comments, but the Director viewing this page hasn't reviewed it"
        end
        _tr.commented do
          _td 'Report has comments not captured yet by secretary (*)'
        end
        _tr.reviewed do
          _td 'Report approved and all comments have been processed by secretary'
        end
      end
    end
    _h2 'Footnotes'
    _p! do
      _ '* The '
      _span.commented 'commented'
      _ ' status generally covers the case where there are enough'
      _ ' preapprovals but comments are present.  However it is also'
      _ ' used when there are NO preapprovals and comments are present.'
      _ ' This covers a number of cases including missing reports for which'
      _ ' an email has been sent, or an inadequete report which the board'
      _ ' is not likely to approve.'
    end
  end
end
