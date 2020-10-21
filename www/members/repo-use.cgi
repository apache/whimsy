#!/usr/bin/env ruby
PAGETITLE = "Scripts that use ASF::SVN" # Wvisible:tools
$LOAD_PATH.unshift '/srv/whimsy/lib'
require 'whimsy/asf'
require 'wunderbar'
require 'wunderbar/bootstrap'
require '../../tools/wwwdocs.rb'
require 'whimsy/logparser'

_html do
  _body? do
    _whimsy_body(
      title: PAGETITLE,
      subtitle: 'Scan all scripts for SVN access',
      relatedtitle: 'More Useful Links',
      related: {
        '/members/log' => 'Full server error and access logs',
        '/docs' => 'Whimsy code and API documentation',
        '/status' => 'Whimsy production server status',
        "https://github.com/apache/whimsy/blob/master/www#{ENV['SCRIPT_NAME']}" => 'See This Source Code'
      },
      helpblock: -> {
        _p.pull_right do
          _ 'This scans the whimsy repo for uses of ASF::SVN, either public or private repos.  It also shows the httpd auth level required to run a script: the graphical key shows which authentication realm is needed.  See also the '
          _a 'listing of all repos used by some common tools.', href: '#majortools'
        end
        emit_authmap
      }
    ) do
      priv, pub = ASF::SVN.private_public
      priv = build_regexp(priv)
      pub = build_regexp(pub)
      scan = scan_dir_svn('../../', [priv, pub])

      _whimsy_panel_table(title: 'Repo use by script') do
        _table.table.table_hover do
          _thead_ do
            _tr do
              _th 'Private repos used'
              _th 'Public repos used'
            end
            scan.each do |file, (privlines, publines, wwwauth, authrealm)|
              _tbody do
                _tr_ do
                  _td :colspan => '2' do
                    emit_auth_level(authrealm)
                    _code file
                    if authrealm.nil? && (privlines.length > 0) && (wwwauth.length == 0)
                      _span.text_warning ' NOTE! Script accesses private repo without apparent auth!'
                    end
                  end
                end
                _tr do
                  _td do
                    privlines.each do |l|
                      _ l
                      _br
                    end
                    wwwauth.each do |w|
                      _ w
                      _br
                    end
                  end
                  _td do
                    publines.each do |l|
                      _ l
                      _br
                    end
                  end
                end
              end
            end
          end
        end
      end

      _whimsy_panel('All repo use by major tools') do
        _ul.list_group id: 'majortools' do
          LogParser::WHIMSY_APPS.each do |path, app|
            # collect tool's worth of lines
            tmp, scan = scan.partition{ |dir, v| dir.match(path) }.map(&:to_h)
            tool = []
            tmp.each do |file, (privlines, publines, wwwauth, authrealm)|
              [privlines, publines].flatten.each do |x|
                tool << x if x.length > 0
              end
            end
            _li!.list_group_item.active do
              _ "#{app} (#{path})"
            end
            tool.uniq.sort.each do |itm|
              _li.list_group_item itm
            end
          end
        end
      end

    end
  end
end