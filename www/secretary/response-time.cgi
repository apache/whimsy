#!/usr/bin/env ruby

$LOAD_PATH.unshift '/srv/whimsy/lib'

require 'whimsy/asf'
require 'wunderbar/jquery'

# only available to ASF members and PMC chairs
user = ASF::Person.new($USER)
unless user.asf_member? or ASF.pmc_chairs.include? user
  print "Status: 401 Unauthorized\r\n"
  print "WWW-Authenticate: Basic realm=\"ASF Members and Officers\"\r\n\r\n"
  exit
end

CMD = 'svn log -l 1 officers/iclas.txt'

_html do
  _style :system
  _h1_ 'Response time test'

  _section_.times do
    _h2 'Times'
    _pre 'running test...'
  end

  _section_.output do
    _h2 'Output'
    _pre class: '_stdin'
    _pre 'loading...', class: '_stdout'
  end

  _script %{
    var startTime = new Date();

    $.get('', '', function(data) {
      data.roundTrip = (new Date() - startTime)/1000;
      $('.output pre._stdin').text(#{CMD.inspect});
      $('.output pre._stdout').text(data.result);
      delete data.result;
      $('.times pre').text(JSON.stringify(data, '', 2));
    }, 'json');
  }
end

_json do
  startTime = Time.now
  _result `#{CMD.sub(/\bofficers\b/, ASF::SVN['officers'])}`
  _server Time.now - startTime
end

