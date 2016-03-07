#!/usr/bin/ruby

$LOAD_PATH.unshift File.realpath(File.expand_path('../../../lib', __FILE__))

#
# SVN Repository status
#

require 'yaml'
require 'wunderbar/bootstrap'
require 'whimsy/asf'

# load list of repositories
repository_file = File.expand_path('../../../repository.yml', __FILE__)
repository = YAML.load_file(repository_file)

_html do
  _link rel: 'stylesheet', href: 'css/status.css'
  _img.logo src: '../whimsy.svg'
  _style %{
    td:nth-child(2), th:nth-child(2) {display: none}
    @media screen and (min-width: 1200px) {
       td:nth-child(2), th:nth-child(2) {display: table-cell}
    }
  }

  writable = true

  _h1_ 'SVN Repository Status'

  _table.table do
    _thead do
      _tr do
        _th 'respository'
        _th 'local path'
        _th 'local revision'
        _th 'server revision'
      end
    end

    _tbody do
      repository[:svn].values.sort_by {|value| value['url']}.each do |svn|
        local = ASF::SVN.find(svn['url']) unless svn['url'] =~ /^https?:/

        color = nil

        if local
          rev = `svn info #{local}`[/^Revision: (.*)/, 1]
          writable &&= File.writable?(local)
        else
          color = 'bg-danger'
        end

        _tr_ class: color do
          _td svn['url'], title: local
          _td local
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
    var local = #{writable};

    // update status of a row based on a sever response
    function updateStatus(tr, response) {
      var tds = $('td', tr);
      tds[2].textContent = response.local;
      tds[3].textContent = response.server;

      // update row color
      if (tds[2].textContent != tds[3].textContent) {
        tr.setAttribute('class', 'bg-warning');

        if (local) {
          $(tds[4]).append('<button class="btn btn-info">update</button>');
          $('button', tr).on('click', sendRequest);
        }
      } else {
        tr.setAttribute('class', 'bg-success');
        if (local) $(tds[4]).empty();
      }
    };

    // when running locally, add a fourth column, and create a function
    // used to send requests to the server
    if (local) {
      $('thead tr').append('<th>action</th');
      $('tbody tr').append('<td></td');

      function sendRequest(event) {
        var tr = event.currentTarget.parentNode.parentNode;
        var action = event.currentTarget.textContent;
        var tds = $('td', tr);
        var name = tds[0].textContent;
        event.currentTarget.disabled = true;
        $.getJSON('?action=' + action + '&name=' + name, function(response) {
          updateStatus(tr, response);
          event.currentTarget.disabled = false;
        });
      }
    }

    // fetch server revision for each row
    $('tbody tr').each(function(index, tr) {
      var tds = $('td', tr);
      var path = tds[0].getAttribute('title');
      if (tds[2].textContent == '') {
        $(tds[4]).append('<button class="btn btn-success">checkout</button>');
        $('button', tr).prop('disabled', true);
      } else {
        $.getJSON('?name=' + tds[0].textContent, function(response) {
          updateStatus(tr, response);
        });
      }
    });
  }
end

# process XMLHttpRequests
_json do
  local_path = ASF::SVN[@name.untaint]
  if local_path
    if @action == 'update'
      `svn cleanup #{local_path.untaint}`
      log = `svn update #{local_path.untaint}`
    end

    repository_url = `svn info #{local_path}`[/^URL: (.*)/, 1]

    {
      log: log.to_s.split("\n"),
      local: `svn info #{local_path.untaint}`[/^Revision: (.*)/, 1],
      server: `svn info #{repository_url.untaint}`[/^Revision: (.*)/, 1]
    }
  end
end

# standalone (local) support
if __FILE__ == $0 and not ENV['GATEWAY_INTERFACE']
  require 'wunderbar/sinatra'

  get '/whimsy.svg' do
    send_file File.expand_path('../../whimsy.svg', __FILE__)
  end

  get '/css/status.css' do
    send_file File.expand_path('../css/status.css', __FILE__)
  end
end
