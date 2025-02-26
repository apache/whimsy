# STV Explorer using Historical data from ASF Board Votes

#####
# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#####

# N.B. This is a copy of the file 
# https://raw.githubusercontent.com/apache/steve/refs/heads/trunk/whatif.rb
# adjusted to remove untaint calls (and fix the jquery reference)
# It's not currently possible to fix the code in Git and use that;
# see members/whatif.cgi for explanation

#
# Prereqs:
#
#   * svn checkout of foundation:voter and foundation:Meetings
#   * Web server with the ability to run cgi (Apache httpd recommended)
#   * Python 2.6.x
#   * Ruby 1.9.x
#   * wunderbar gem ([sudo] gem install wunderbar)
#   * (optional) jQuery http://code.jquery.com/jquery-min.js
#
# Installation instructions:
#
#    ruby whatif.rb --install=/var/www
#
#    1) Specify a path that supports cgi, like public-html or Sites.
#    2) (optional, but highly recommended) download jquery-min.js into
#       your installation directory.
#
# Execution instructions:
#
#   Point your web browser at your cgi script.  For best results, use
#   Firefox 4 or a WebKit based browser, like Google Chrome.



MEETINGS  = File.expand_path('../Meetings') unless defined? MEETINGS
WHATIF = './whatif.py' unless defined? WHATIF

require 'wunderbar'
require 'tempfile'

def raw_votes(date)
  all_votes = Dir["#{MEETINGS}/*/raw_board_votes.txt"]
  if date
    result = "#{MEETINGS}/#{date}/raw_board_votes.txt"
  else
    result = all_votes.sort.last
  end
  result
end

def ini(vote)
  vote.sub('/raw_','/').sub('votes.','nominations.').sub('.txt','.ini')
end

def filtered_election(votes, seats, candidates)
  list = candidates.join(' ')

  output = `#{WHATIF} #{votes} #{seats} #{list}`
  output.scan(/.*elected$/).inject(Hash.new('none')) do |results, line|
    name, status = line.scan(/^(.*?)\s+(n?o?t?\s?elected)$/).flatten
    results.merge({name.gsub(/[^[[:alnum:]]]/,'') => status.gsub(/\s/, '-')})
  end
end

# XMLHttpRequest (AJAX)
_json do
  nominees = File.read(ini(raw_votes(@date))).scan(/^\w:\s*(.*)/).flatten
  candidates = params.keys & nominees.map {|name| name.gsub(/[^[[:alnum:]]]/,'')}
  _! filtered_election(raw_votes(@date), @seats, candidates)
end

# main output
_html do
  _head_ do
    _title 'STV Explorer'
    _style! %{
       h1 {font-family: sans-serif; font-weight: normal}
       select {display: block; margin: 0 0 1em 1em; font-size: 140%}
       label div {display: inline-block; min-width: 12em; font-size: x-large}
       label div {-webkit-transition: background-color 1s}
       label div {-moz-transition: background-color 1s}
       label {float: left; clear: both}
       label[for=seats] {display: inline; line-height: 500%}
       p, input[type=checkbox] {margin-left: 1em}
       p, input[type=submit] {display: block; clear: both}
       .elected {background: #0F0}
       .not-elected {background: #F00}
       .none {background: yellow}
    }
    _script src: '../jquery-min.js'
  end

  _body? do
    _h1_ 'STV Explorer'

    nominees = Hash[File.read(ini(raw_votes(@date))).scan(/^\w:\s*(.*)/).
      flatten.map {|name| [name.gsub(/[^[[:alnum:]]]/,''), name]}]
    candidates = params.keys & nominees.keys
    candidates = nominees.keys if candidates.empty? or @reset

    @seats ||= '9'
    results = filtered_election(raw_votes(@date), @seats, candidates)

    # form of nominees and seats
    _form method: 'post', id: 'vote' do
      _select name: 'date' do
        Dir["#{MEETINGS}/*/raw_board_votes.txt"].sort.reverse.each do |votes|
	  next unless File.exist? ini(votes)
	  date = votes[/(\d+)\/raw_board_votes.txt$/,1]
          display = date.sub(/(\d{4})(\d\d)(\d\d)/,'\1-\2-\3')
          _option display, value: date, selected: (votes == raw_votes(@date))
	end
      end

      nominees.sort.each do |id, name|
        _label_ id: id do
          _input type: 'checkbox', name: id, checked: candidates.include?(id)
          _div name, class: results[id]
        end
      end

      _label_ for: 'seats' do
        _span 'seats:'
        _input name: 'seats', id: 'seats', value: @seats, size: 2,
          type: 'number', min: 1, max: nominees.length-1
      end

      _input type: 'submit', value: 'submit', name: 'submit'
    end

    _p_ do
      _a "Member's Meeting Information",
        href: 'https://whimsy.apache.org/members/meeting'
    end

    _script %{
      // submit form using XHR; update class for labels based on results
      function refresh() {
        $.post('', $('#vote').serialize(), function(results) {
          for (var name in results) {
            $('#'+name+' div').attr('class', results[name]);
          }
        }, 'json');
        return false;
      }

      // On checkbox click, remove class from associated label & refresh
      $(':checkbox').click(function() {
        $('div', $(this).parent()).attr('class', 'none');
        refresh();
      });

      // reset whenever the date changes
      $('select').change(function() {
        $('input[value=submit]').attr('name', 'reset');
        $('input[value=submit]').click();
      });

      // If JS is enabled, we don't need a submit button
      $('input[type=submit]').hide();

      // Refresh on change in number of seats
      $('#seats').on('input', function() {return refresh()});
    }
  end
end

__END__
MEETINGS = '../Meetings'
