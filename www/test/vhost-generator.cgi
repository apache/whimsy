#!/usr/bin/ruby1.9.1

require 'wunderbar'

# response to form requests
if ENV['REQUEST_METHOD'].upcase == 'POST'
  cgi = CGI.new
  cgi.out 'type' => 'text/plain' do
    hostname = cgi.params['hostname'].first
    docroot = cgi.params['docroot'].first

    conf = File.read(Dir['/etc/apache2/sites-available/*whimsy*.conf'].first)

    conf[/<VirtualHost (.*)>/, 1] = hostname
    conf.gsub! '/srv/whimsy', docroot.chomp('/')

    conf
  end

  exit 0
end

# form used for tailoring vhosts
_html do
  _style %{
    label {width: 12em; float: left}
    legend {background: #141; color: #DFD; padding: 0.4em}
    fieldset {background: #EFE; width: 34em}
    fieldset div {clear: both; padding: 0.4em 0 0 1.5em}
    input,textarea {width: 3in}
    select {width: 3.06in}
    input[type=checkbox] {margin-left: 6em; width: 1em}
    input[type=submit] {margin-top: 0.5em; margin-left: 3em; width: 8em}
  }

  _form method: 'post' do
    _fieldset do
      _legend 'Apache Whimsy vhost generator'

      _div_ do
        _label 'Virtual host name', for: 'hostname'
        _input id: 'hostname', name: 'hostname', required: true,
          pattern: '^(?![0-9]+$)(?!-)[a-zA-Z0-9-]{,63}(?<!-)$',
          value: 'whimsy.local'
      end

      _div_ do
        _label 'Document root', for: 'docroot'
        _input id: 'docroot', name: 'docroot', required: true,
          pattern: '^/([^\\(){}:\*\?<>\|\"\'])+$',
          value: '/srv/whimsy'
      end

      _input type: 'submit', value: 'Submit'
    end
  end

  _script %{
    var inputs = Array.prototype.slice.call(document.querySelectorAll("input"));
    var submit = document.querySelector("input[type=submit]");

    inputs.forEach(function(input) {
      input.addEventListener("input", function() {
        if (inputs.some(function(input) {
          return input.matches(":invalid")
        })) {
          submit.disabled = true
        } else {
          submit.disabled = false
        }
      })
    })
  }
end
