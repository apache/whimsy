#!/usr/bin/env ruby
PAGETITLE = "Hardcoded Data In Code" # Wvisible:tools data

$LOAD_PATH.unshift '/srv/whimsy/lib'
require 'json'
require 'whimsy/asf'
require 'wunderbar'
require 'wunderbar/bootstrap'
GITWHIMSY = 'https://github.com/apache/whimsy/blob/master/'
HARDCODED = 'hardcoded.json'
hclist = JSON.parse(File.read(HARDCODED))

_html do
  _body? do
    _whimsy_body(
      title: PAGETITLE,
      related: {
        "https://github.com/apache/whimsy/blob/master/DEVELOPMENT.md" => "Whimsy Dev Environment Setup",
        "/public" => "Whimsy public JSON datafiles",
        "/docs" => "Whimsy code/API developer documentation"
      },
      helpblock: -> {
        _p %{ Whimsy tools integrate directly with a wide variety of
          private and public data and processes within the ASF.  Many
          tools also hardcode lists or mappings of data that is
          canonically stored elsewhere.  This is a partial list.
        }
        _p %{ Many of these hardcoded lists are good things, and are
          in the right part of the code.  Some lists may turn out to
          be better stored elsewhere, either in Whimsy or other repos.
        }
      }
    ) do
      _ul.list_group do
        hclist.each do |file, info|
          _li.list_group_item do
            _a '', name: file.gsub(/[#%\[\]\{\}\\"<>]/, '')
            _code! do
              if info['line']
                _a! file, href: "#{GITWHIMSY}#{file}#L#{info['line']}"
              else
                _a! file, href: "#{GITWHIMSY}#{file}"
              end
              _span.text_muted " #{info['symbol']}"
            end
            _br
            _ " #{info['description']}"
          end
        end
      end
    end
  end
end
