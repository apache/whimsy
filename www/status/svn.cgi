#!/usr/bin/ruby1.9.1

$LOAD_PATH.unshift File.realpath(File.expand_path('../../../lib', __FILE__))

#
# SVN Repository status
#

require 'yaml'
require 'wunderbar/bootstrap'
require 'whimsy/asf'

repository_file = File.expand_path('../../../repository.yml', __FILE__)
repository = YAML.load_file(repository_file)

_html do
  _link rel: 'stylesheet', href: 'css/status.css'
  _img.logo src: '../whimsy.svg'

  _h1_ 'SVN Repository Status'

  _table.table do
    _thead do
      _tr do
        _th 'respository'
        _th 'local revision'
        _th 'server revision'
      end
    end

    _tbody do
      repository[:svn].values.sort_by {|value| value['url']}.each do |svn|
        local = ASF::SVN[svn['url']] unless svn['url'] =~ /^https?:/

        color = nil

        if local
          rev = `svn info #{local}`[/^Revision: (.*)/, 1]
        else
          color = 'bg-danger'
        end

        _tr_ class: color do
          _td svn['url'], title: local
          _td rev
          if local
            _td '(loading)'
          else
            _td
          end
        end
      end
    end
  end

  _script %{
    // fetch server revision for each row
    $('tbody tr').each(function(index, tr) {
      var tds = $('td', tr);
      var path = tds[0].getAttribute('title');
      if (tds[1].textContent == '') return;
      $.getJSON('?name=' + tds[0].textContent, function(response) {
        tds[2].textContent = response.rev;

        // update row color
        if (tds[1].textContent != tds[2].textContent) {
          tr.classList.add('bg-warning');
        } else {
          tr.classList.add('bg-success');
        }
      });
    });
  }
end

_json do
  local_path = ASF::SVN[@name.untaint]
  if local_path
    repository_url = `svn info #{local_path}`[/^URL: (.*)/, 1]
    {rev: `svn info #{repository_url.untaint}`[/^Revision: (.*)/, 1]}
  end
end
