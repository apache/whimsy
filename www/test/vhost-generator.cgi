#!/usr/bin/env ruby

require 'wunderbar'

# response to form requests
if ENV['REQUEST_METHOD'].to_s.upcase == 'POST'
  cgi = CGI.new
  cgi.out 'type' => 'text/plain' do
    # extract parameters
    hostname = cgi.params['hostname'].first
    docroot = cgi.params['docroot'].first
    https = cgi.params['https'].first

    # read live configuration
    conf = File.read(Dir['/etc/apache2/sites-available/*whimsy*.conf'].first)

    # enable all interfaces
    conf[/<VirtualHost (.*):\d+>/, 1] = '*'

    # replace hostname
    conf[/ServerName (.*)/, 1] = hostname

    # don't override error or custom logs
    conf[/()ErrorLog/, 1] = '# '
    conf[/()CustomLog/, 1] = '# '

    # disable Passenger Default user and group (if present)
    begin
        conf[/()PassengerDefaultUser/, 1] = '# '
    rescue
    end
    begin
        conf[/()PassengerDefaultGroup/, 1] = '# '
    rescue
    end

    # global replace docroot
    conf.gsub! '/srv/whimsy', docroot.chomp('/')

    # global replace docroot
    conf.gsub! /SetEnv HTTPS .*/, "SetEnv HTTPS #{https}"

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

    ul {padding: 0; display: flex; flex-wrap: wrap}
    li {width: 10%; list-style-type: none; margin: 0 2em}
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

      _div_ do
        _label 'HTTPS', for: 'https'
        _select id: 'https', name: 'https' do
          _option 'on'
          _option 'off', selected: true
        end
      end

      _input type: 'submit', value: 'Submit'
    end

    _h3 'Modules enabled'
    _ul do
      Dir['/etc/apache2/mods-enabled/*.load'].sort.each do |conf|
        _li File.basename(conf, '.load')
      end
    end
  end

  _script %{
    var inputs = Array.prototype.slice.call(document.querySelectorAll("input"));
    var submit = document.querySelector("input[type=submit]");

    // only enable submit button when all inputs are valid
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
