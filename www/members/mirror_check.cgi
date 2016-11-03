#!/usr/bin/env ruby

require "../../tools/mirror_check.rb"

_html do
  _style %{
    textarea, .mod, label {display: block}
    input[type=submit] {display: block; margin-top: 1em}
    input[name=podling], p, .mod, textarea {margin-left: 2em}
    .subdomain, .domain {color: #000}
    legend {background: #141; color: #DFD; padding: 0.4em}
#    .name {width: 6em}
    ._stdin {color: #C000C0; margin-top: 1em}
    ._stdout {color: #000}
    .error, ._stderr {color: #F00}
    .request {background-color: #BDF}
  }

  _body? do
    _h2 "Mirror Checker"
    _p do
      _ 'This page can be used to check that an Apache software mirror has been set up correctly'
    end
    _p do
      _ 'Please see the'
      _a 'Apache how-to mirror page', href: 'http://www.apache.org/info/how-to-mirror.html'
      _ 'for the full details on setting up an ASF mirror.'
    end

    _form method: 'post' do
      _fieldset do
        _legend 'ASF Mirror Check Request'
        _ 'Mirror URL'
        _input.name name: 'url', required: true,
                    value: ENV['QUERY_STRING'],
                    placeholder: 'mirror URL',
                    size: 50
        _input type: 'submit', value: 'Check Mirror'
      end
    end

    if _.post?
      doPost(@url)
    end
  end
end
