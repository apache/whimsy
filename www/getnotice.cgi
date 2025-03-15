#!/usr/bin/env ruby

# Provide access to Status.notice method from Javascript

$LOAD_PATH.unshift '/srv/whimsy/lib'

require 'wunderbar'
require 'whimsy/asf/status'

noticetext, noticepath, noticeclass = Status.notice

_json do
  if noticetext
    {noticetext: noticetext, noticepath: noticepath, noticeclass: noticeclass}
  else
    {noticetext: nil}
  end
end
