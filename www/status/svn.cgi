#!/usr/bin/env ruby

$LOAD_PATH.unshift '/srv/whimsy/lib'

#
# SVN Repository status
#

require 'wunderbar/bootstrap'
require 'whimsy/asf'

# load list of repositories
repository = ASF::SVN.repo_entries

svnrepos = Array(ASF::Config.get(:svn))

_html do
  _link rel: 'stylesheet', href: 'css/status.css'
  _img.logo src: '../whimsy.svg'
  _style %{
    td:nth-child(2), th:nth-child(2) {display: none}
    @media screen and (min-width: 1200px) {
       td:nth-child(2), th:nth-child(2) {display: table-cell}
    }
  }

  # remains true if all local checkouts are writable
  writable = true
  svnroot = (svnrepos.length == 1 && svnrepos.first =~ /^(\/\w[-.\w]*)+\/\*$/ &&
    File.writable?(svnrepos.first.chomp('*')))

  _h1_ 'SVN Repository Status'

  _table_.table do
    _thead do
      _tr do
        _th 'repository'
        _th 'local path'
        _th 'local last changed revision'
        _th 'server last changed revision'
      end
    end

    _tbody do
      repository.sort_by {|name, value| value['url']}.each do |name, svn|
        local = ASF::SVN.find(svn['url']) unless svn['url'] =~ /^https?:/

        color = nil

        if local
          rev = ASF::SVN.getInfoItem(local,'last-changed-revision')
          writable &&= File.writable?(local)
        else
          color = 'bg-danger'
        end

        _tr_ class: color do
          _td! title: local do
            _a svn['url'], href: ASF::SVN.svnpath!(name)
          end

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
    var writable = #{writable};
    var svnroot = #{!!svnroot};

    // update status of a row based on a sever response
    function updateStatus(tr, response) {
      var tds = $('td', tr);
      [1,2,3].forEach(function(i) {
         tds[i].textContent = '?' // show response has arrived at least
      });
      if (response.path) tds[1].textContent = response.path;
      if (response.local) tds[2].textContent = response.local;
      if (response.server) tds[3].textContent = response.server;

      // update row color
      if (tds[2].textContent != tds[3].textContent) {
        tr.setAttribute('class', 'bg-warning');

        if (writable) {
          $(tds[4]).html('<button class="btn btn-info">update</button>');
          $('button', tr).on('click', sendRequest);
        }
      } else {
        tr.setAttribute('class', 'bg-success');
        if (writable) $(tds[4]).empty();
      }
    };

    // when running locally, add a fourth column, and create a function
    // used to send requests to the server
    if (writable) {
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
          updateAll();
        });
      }

      // add checkout buttons
      if (svnroot) {
        $('tbody tr').each(function(index, tr) {
          var tds = $('td', tr);
          var path = tds[0].getAttribute('title');
          if (tds[2].textContent == '') {
            $(tds[4]).html('<button class="btn btn-success">checkout</button>');
            $('button', tr).on('click', sendRequest);
          }
        })
      };
    }

    // fetch server revision for each row
    function updateAll() {
      $('tbody tr').each(function(index, tr) {
        var tds = $('td', tr);
        var path = tds[0].getAttribute('title');
        if (tds[2].textContent != '') {
          $.getJSON('?name=' + tds[0].textContent, function(response) {
            updateStatus(tr, response);
          });
        }
      });
    }

    updateAll();
  }
end

# process XMLHttpRequests
_json do
  local_path = ASF::SVN.find(@name)
  if local_path
    if @action == 'update'
      log = `svn cleanup #{local_path} 2>&1`
      log = log + `svn update #{local_path} 2>&1`
    end

    info, err = ASF::SVN.getInfo(local_path)
    repository_url = info[/^URL: (.*)/, 1] if info

  else
    if @action == 'checkout'

      repo = repository.find {|name, value| value['url'] == @name}
      local_path = svnrepos.first.chomp('*') + repo.first

      repository_url = @name
      unless repository_url =~ /^https?:/
        repository_url = ASF::SVN.svnpath!(repository_url)
      end

      log = `svn checkout #{repository_url} #{local_path} 2>&1`
    end
  end

  localrev, lerr = ASF::SVN.getInfoItem(local_path,'last-changed-revision')
  if repository_url
    serverrev, serr = ASF::SVN.getInfoItem(repository_url,'last-changed-revision')
    {
      log: log.to_s.split("\n"),
      path: local_path,
      local: localrev || lerr.split("\n").last, # generally the last SVN error line is the cause
      server: serverrev || serr.split("\n").last
    }
  else
    {
      log: log.to_s.split("\n"),
      path: local_path,
      local: localrev || lerr.split("\n").last, # generally the last SVN error line is the cause
      server: "ERROR: no repository found for name,local_path: #{@name},#{local_path}"
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
