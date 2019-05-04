#!/usr/bin/env ruby
##   Licensed to the Apache Software Foundation (ASF) under one or more
##   contributor license agreements.  See the NOTICE file distributed with
##   this work for additional information regarding copyright ownership.
##   The ASF licenses this file to You under the Apache License, Version 2.0
##   (the "License"); you may not use this file except in compliance with
##   the License.  You may obtain a copy of the License at
## 
##       http://www.apache.org/licenses/LICENSE-2.0
## 
##   Unless required by applicable law or agreed to in writing, software
##   distributed under the License is distributed on an "AS IS" BASIS,
##   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
##   See the License for the specific language governing permissions and
##   limitations under the License.

PAGETITLE = "Apache Mailing list Request Form" # Wvisible:infra mail list
$LOAD_PATH.unshift '/srv/whimsy/lib'
require 'wunderbar'
require 'shellwords'
require 'mail'
require 'whimsy/asf'
require 'whimsy/asf/rack'
require 'whimsy/asf/podlings'
require 'whimsy/asf/site'
require 'tmpdir'
require 'fileutils'

# This is a version number check embedded in the json files.
# 
# The script started generating format numbers on 2012-08-28 but had been
# in production for some number before that.
FORMAT_NUMBER = 4

user = ASF::Auth.decode(env = {})

AUTHORIZED = (user.asf_member? or ASF.pmc_chairs.include?(user))
if !AUTHORIZED && env['REQUEST_METHOD'].to_s != 'GET'
  print "Status: 401 Unauthorized\r\n"
  print "WWW-Authenticate: Basic realm=\"ASF Members and Officers\"\r\n\r\n"
  exit
end

lists = ASF::Mail.lists
pmcs = ASF::Committee.pmcs.map(&:mail_list)
pmcs.delete_if {|pmc| not lists.include? "#{pmc}-private"}

# INFRA-11555
# The validation done by this script must agree with the validation done by
# the script that processes the json files:
# https://svn.apache.org/repos/infra/infrastructure/trunk/mlreq/queuerun.py
  
MLID_PAT = '^[a-z0-9]+(-[a-z0-9]+)?$'
# TLPs may include '-' in name e.g. empire-db
# TODO tighten RE to match only a single non-leading '-'
PROJ_PAT = '^[a-z][-a-z0-9]+$'
# Podlings cannot include '-' (don't want any more hyphenated names)
POD_PAT = '^[a-z][a-z0-9]+$'

_html do

  incubator = (ENV['PATH_INFO'].to_s.include? 'incubator')

  _head_ do
    if incubator
      _title 'ASF Incubator Mailing List Request'
    else
      _title 'ASF Mailing List Request'
    end
    _script src: '/jquery-min.js'
    _style %{
      textarea, .mod, label {display: block}
      input[type=submit] {display: block; margin-top: 1em}
      input[name=podling], input[type=checkbox], input[type=radio], p, .mod, textarea {margin-left: 2em}
      .subdomain, .domain {color: #000}
      legend {background: #141; color: #DFD; padding: 0.4em}
      .name {width: 6em}
      ._stdin {color: #C000C0; margin-top: 1em}
      ._stdout {color: #000}
      .error, ._stderr {color: #F00}
      .request {background-color: #BDF}
    }
  end

  _body? do
    if _.post?
      tmpdir = Dir.mktmpdir
      at_exit { FileUtils.remove_entry tmpdir }

      _.system [
        'svn', 'checkout', '--no-auth-cache', '--non-interactive',
        (['--username', env.user, '--password', env.password] if env.password),
        'https://svn.apache.org/repos/infra/infrastructure/trunk/mlreq/input',
        tmpdir + '/mlreq'
      ]

      Dir.chdir tmpdir + '/mlreq'

      # extract moderators from input fields or text area
      mods = params.select {|name,value| name =~ /^mod\d+$/ and value != ['']}.
        values.flatten.join(',')
      mods = @mods.strip.gsub(/\s+/,',') if @mods

      # build a queue of requests
      queue = []

      unless incubator
        queue << {
          version: FORMAT_NUMBER,
          type: 'toplevel',
          private: (@private == 'true' || @localpart == 'private' || @localpart == 'security'),
          subdomain: @subdomain,
          localpart: @localpart,
          domain: @domain || 'apache.org',
          moderators: mods,
          muopts: @muopts,
          replytolist: (@replyto == "true"),
          notifyee: "private@#{@subdomain}.apache.org"
        }
      else # incubator request
        params.keys.grep(/^suffix\d+/).each do |name|
          suffix = params[name].first
          next if suffix.empty?
          queue << {
            version: FORMAT_NUMBER,
            type: 'podling',
            private: (params[name.sub('suffix','private')].first == 'true' || suffix == 'private' || suffix == 'security'),
            subdomain: @podling,
            outhost: "#{@podling}.incubator.apache.org",
            localpart: suffix,
            domain: @domain || 'apache.org',
            moderators: mods,
            muopts: @muopts,
            replytolist: (@replyto == "true"),
            notifyee: "private@incubator.apache.org"
          }
        end
      end

      # build a list of validation errors
      errors = []

      # TODO this list ought to be synchronized with the patterns applied to the HTML fields
      checks = {
        localpart: Regexp.new(MLID_PAT),
        subdomain: Regexp.new(PROJ_PAT),
        domain: /^apache[.]org$/,
        muopts: /^(mu|Mu|mU)$/,
        notifyee: /^\w+[@]\w+[.]apache[.]org$/
      }

      queue.each do |vars|
        checks.each do |name, pattern|
          if pattern and vars[name] !~ pattern
            errors << "Invalid #{name}: #{vars[name].inspect}"
          end
        end

        vars[:moderators].split(',').each do |email|
          begin
            if email != Mail::Address.new(email).address
              errors << "Invalid email: #{email.inspect}"
            end
            if email =~ /@apache\.org$/ and not ASF::Person.find_by_email(email)
              errors << "Account does not exist: #{email.inspect}"
            end
          rescue
            errors << "Invalid email: #{email.inspect}"
          end
        end

        unless incubator or pmcs.include? vars[:subdomain]
          errors << "Invalid PMC: #{vars[:subdomain]}"
        end

        mlreq = "#{vars[:subdomain]}-#{vars[:localpart]}".gsub(/[^-\w]/,'_')
        if File.exist? "#{mlreq.untaint}.json"
          errors << "Already submitted: " +
            "#{vars[:localpart]}@#{vars[:subdomain]}.#{vars[:domain]}"
        end
      end

      # output requests or errors
      tocommit = []
      if errors.empty?
        _h2_ "Submitted request(s)"
        queue.each do |vars|
          mlreq = "#{vars[:subdomain]}-#{vars[:localpart]}".
                    gsub(/[^-\w]/,'_')
          vars[:message] = @message unless @message.empty?
          request = JSON.pretty_generate(vars) + "\n"
          _pre.request request
          vars[:mlreq] = "#{mlreq.untaint}.json"
          File.open(vars[:mlreq],'w') { |file| file.write request }
          _.system(['svn', 'add', '--', vars[:mlreq]])
          tocommit << vars[:mlreq]
        end

        if incubator
          # Use '+' so it sorts first.
          mlreq = "#{queue.first[:subdomain]}".gsub(/[^-\w]/,'_')
          mlreq = "#{mlreq.untaint}+.json"
          File.open(mlreq, 'w') { |file|
            file.write JSON.pretty_generate({
              version: FORMAT_NUMBER,
              type: 'dirs',
              subdomain: queue.first[:subdomain],
            }) + "\n"
          }
          _.system(['svn', 'add', '--', mlreq])
          tocommit << mlreq
        end

        if queue.length == 1
          vars = queue.first
          request = "#{vars[:localpart]}@#{vars[:subdomain]}.apache.org"
        else
          request = "#{@podling}-* (podling)"
        end

        _.system [
          'svn', 'commit', '--no-auth-cache', '--non-interactive',
          '-m', "#{request} mailing list request by #{env.user} via " + 
            ENV['SERVER_NAME'],
          (['--username', env.user, '--password', env.password] if env.password),
          '--', *tocommit
        ]
        _p do
          _strong "Next steps:"
          _ "We will create the lists and email"
          _ Hash[queue.map { |vars| [vars[:notifyee],1] }].
                       keys.sort.join(', ')
          _ "once we have done that."
          _{"There is <em>no need</em> to file a JIRA."}
        end
      else
        _h2_.error 'Form not submitted due to errors'
        _ul do
          errors.each { |error| _li error }
        end
      end
    end

    unless _.post?
      _p do
        if incubator
          _ "Looking to create a non-Incubator mailing list?  Try"
          _a "ASF Mailing List Request", href: '../mlreq'
          _ 'instead.'
        else
          _ "Looking to create a Incubator mailing list?  Try"
          _a "ASF Incubator Mailing List Request", href: 'mlreq/incubator'
          _ 'instead.'
        end
      end
    end
    
    _form method: 'post' do
      _fieldset do
        if incubator
          _legend 'ASF Incubator Mailing List Request'

          _h3_ 'Podling name'
          _input.name name: 'podling', required: true, pattern: POD_PAT,
            placeholder: 'name'

          _h3_ 'List name'
          _div.list do
            _input type: 'checkbox', name: 'private1', value: 'true'
            _input.name.list name: 'suffix1', required: true, 
              placeholder: 'list', pattern: MLID_PAT
            _ '@'
            _input.name.podling disabled: true, placeholder: '<podling>'
            _ '.'
            _input.name.subdomain value: 'incubator', disabled: true
            _ '.'
            _input.name.domain value: 'apache.org', disabled: true
          end
          _p "Check box next to lists which are to have private archives."
        else
          _legend 'ASF Mailing List Request'

          _h3_ 'List name'
          _input type: 'checkbox', name: 'private', value: 'true'
          _input.name name: 'localpart', required: true, pattern: MLID_PAT,
            placeholder: 'name'
          _ '@'
          _select name: 'subdomain' do
            pmcs.sort.each do |pmc|
              _option pmc unless pmc == 'incubator'
            end
          end
          _ '.'
          _input.name.domain value: 'apache.org', disabled: true
          _p "Check box if list archives are to be private."
        end
        _p do
          _ "Lists named "
          _code 'private'
          _ "or"
          _code 'security'
          _ "will always have private archives,"
          _ "whether or not the box is checked."
        end

        _h3_ 'Replies'
        _label do
          _input type: 'checkbox', name: 'replyto', value: 'true', checked: true
          _ 'Set Reply-To list header?'
        end
        _p! do
          _ "If checked, replies will go to the same list.  "
          _ "Except for lists named "
          _code 'commits'
          _ ", which will direct replies to the corresponding "
          _code 'dev'
          _ " list."
        end

        _h3_ 'Moderation'
        _label do
          _input type: "radio", name: "muopts", value: "mu", required: true,
            checked: true
          _ 'allow subscribers to post, moderate all others'
        end
        _label do
          _input type: "radio", name: "muopts", value: "Mu"
          _ 'allow subscribers to post, reject all others'
        end
        _label do
          _input type: "radio", name: "muopts", value: "mU"
          _ 'moderate all posts'
        end
        _p do
          _ "Lists named"
          _code 'private'
          _ "always permit posts by non-subscribers."
        end

        _h3_ 'Moderators\' addresses'
        _textarea.mods! name: 'mods'

        _h3_ 'Notes'
        _textarea name: 'message', cols: 70

        if AUTHORIZED
          _input type: 'submit', value: 'Submit Request'
        else
          _input type: 'submit', value: 'Only ASF Members and Officers may submit mailing list requests', disabled: true
        end
      end
    end

    _script_ %{
      // replace moderator textarea with two input fields
      $('#mods').replaceWith('<input type="email" required="required" ' +
        'class="mod" name="mod0" placeholder="email"/>')
      $('.mod:last').after('<input type="email" required="required" ' +
        'class="mod" name="mod1" placeholder="email"/>')

      // initially disable suffix and private (until podling is entered)
      $('input[name=suffix1]').attr('disabled', true);
      $('input[name=private1]').attr('disabled', true);

      // process keystrokes for moderator input fields
      var mkeyup = function() {
        // when there are no more empty moderator fields, add one more
        if (!$('.mod').filter(function() {return $(this).val()==''}).length) {
          var input = $('<input type="email" class="mod" value=""/>');
          input.attr('name', 'mod' + $('.mod').length);
          input.bind('input', mkeyup);
          lastmod.after(input);
          lastmod = input;
        }

        // split on commas and spaces
        var comma = $(this).val().search(/[, ]/);
        if (comma != -1) {
          lastmod.val($(this).val().substr(comma+1)).focus().trigger('input');
          $(this).val($(this).val().substr(0,comma));
        } else if ($(this).val() == '' && this != lastmod[0]) {
          if (!$(this).attr('required')) $(this).remove();
        }
      }

      // process keystrokes for podling input fields
      var pkeyup = function() {
        if ($(this).val() != '') {
          $('input[type=checkbox]', $(this).parent()).removeAttr('disabled');
          var div = $(this).parent().clone();
          var input = $('input:not(:disabled)', div);
          input.attr('name', 'suffix' + ($('div.list').length+1)).val('').
            attr('required', false).bind('input', pkeyup);
          $('input[type=checkbox]', div).attr('disabled', true).
            prop('checked', false).
            attr('name', 'private' + ($('div.list').length+1));
          lastpod.unbind().bind('input', function() {
            if ($(this).val() == 'private' || $(this).val() == 'security') {
              $('input[type=checkbox]', $(this).parent()).prop('checked', true);
            }
          });
          lastpod.parent().after(div);
          lastpod = input;
        }
      }

      // initial bind of keystroke handlers
      var lastmod = $('.mod:last');
      var lastpod = $('div.list:last input[required]');
      $('.mod').bind('input', mkeyup);
      lastpod.bind('input', pkeyup);

      // whenever podling is set, copy values and enable suffix
      $('input[name=podling]').bind('input', function() {
        if ($(this).val() != '') {
          $('input.podling').val($(this).val()).css('color', '#000');
          $('input[name=suffix1]').removeAttr('disabled');
        }
      }).trigger('keyup');

      var message = $('<h2>Validating form fields</h2>');
      message.hide();
      $('p:last').after(message);
      validated = false;

      // prevalidate the form before actual submission
      $('form').submit(function() {
        message.show();
        if (!validated) {
          $.post('', $('form').serialize(), function(_) {
            var resubmit = false;

            // perform the server indicated actions
            if (_.ok) {
              validated = resubmit = true;
            } else if (_.confirm) {
              if (confirm(_.confirm)) {
                resubmit = true;
              } else {
                _.validated = {}
              }
            } else {
              alert(_.alert || _.exception || 'Server error');
            }

            // mark confirmed and checked fields as validated
            for (var name in _.validated) {
              if (!$('input[name='+name+']').length) {
                $('form').append('<input type="hidden" name="'+name+'"/>');
              }
              $('input[name='+name+']').val(_.validated[name]);
            }

            // complete the action, hide the message, and optionall resubmit
            if (_.focus) $(_.focus).focus();
            message.hide();
            if (resubmit) $('form').submit();
          }, 'json');
          return false;
        };
      });
    }
  end
end

_json do
  validated = {}
  _validated validated

  # confirm if podling is new (has no existing lists)
  if @podling != @confirmed_podling
    validated['confirmed_podling'] = @podling
    if not lists.any? {|list| list.sub(/^incubator-/, '').start_with? "#{@podling}-"}

      # extract the names of podlings (and aliases) from podlings.xml
      require 'nokogiri'
      incubator_content = ASF::SVN['incubator-content']
      current = Nokogiri::XML(File.read(File.join(incubator_content, 'podlings.xml'))).
        search('podling[status=current]')
      podlings = current.map {|podling| podling['resource']}
      podlings += current.map {|podling| podling['resourceAliases']}.compact.
        map {|names| names.split(/[, ]+/)}.flatten

      if not podlings.include? @podling
        _confirm "Podling #{@podling} not found.  Continue?"
        next _focus 'input[name=podling]'
      end
    end
  end

  # confirm if pmc is unknown
  if @subdomain != @confirmed_localpart
    validated['confirmed_localpart'] = @subdomain
    if not pmcs.include? @subdomain
      _confirm "PMC #{@subdomain} not found.  Continue?"
      next _focus 'input[name=subdomain]'
    end
  end

  # alert if incubator list requested already exists
  params.keys.grep(/^suffix\d+$/).each do |param|
    next if params[param].first.empty?
    localpart = "#{@podling}-#{params[param].first}"
    if lists.any? {|list| list == "incubator-#{localpart}"}
      _alert "List #{localpart}@incubator.apache.org already exists."
      _focus "input[name=#{param}]"
      break
    end
    if lists.any? {|list| list == localpart}
      _alert "List #{localpart}.apache.org already exists."
      _focus "input[name=#{param}]"
      break
    end
  end

  # alert if non-incubator list requested already exists
  if @localpart
    if lists.any? {|list| list == "#{@subdomain}-#{@localpart}"}
      _alert "List #{@localpart}@#{@subdomain}.apache.org already exists."
      _focus "input[name=localpart]"
    end
  end

  next if _['alert']

  # confirm if moderator email is unknown
  params.keys.grep(/^mod\d+$/).each do |param|
    email = params[param].first
    next if email.empty?
    next if params.any? do |key,value| 
      key =~ /^confirmed_mod/ && value.first == email
    end

    validated["confirmed_#{param}"] = email
    if not ASF::Person.find_by_email(email)
      _confirm "Unknown E-mail #{email}.  Proceed with a non-committer moderator?"
      _focus "input[name=#{param}]"
      break
    end
  end

  _ok 'OK' if not _['confirm']
end
