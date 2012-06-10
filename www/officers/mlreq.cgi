#!/usr/bin/ruby1.9.1
require 'wunderbar'
require 'shellwords'
require 'mail'
require '/var/tools/asf'

user = ASF::Person.new($USER)
unless user.asf_member? or ASF.pmc_chairs.include? user or $USER=='ea'
  print "Status: 401 Unauthorized\r\n"
  print "WWW-Authenticate: Basic realm=\"ASF Members and Officers\"\r\n\r\n"
  exit
end

lists = ASF::Mail.lists
pmcs = ASF::Committee.list.map(&:mail_list)
pmcs.delete_if {|pmc| not lists.include? "#{pmc}-private"}

_html do

  incubator = (env['PATH_INFO'].to_s.include? 'incubator')

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
      legend {background: #141; color: #DFD; padding: 0.4em}
      .name {width: 6em}
      ._stdin {color: #C000C0; margin-top: 1em}
      ._stdout {color: #000}
      ._stderr {color: #F00}
    }
  end

  _body? do
    _form method: 'post' do
      _fieldset do
        if incubator
          _legend 'ASF Incubator Mailing List Request'

          _h3_ 'Podling name'
          _input.name name: 'podling', required: true, pattern: '^\w+$',
            placeholder: 'name'

          _h3_ 'List name'
          _div.list do
            _input.name.podling disabled: true, value: '<podling>', 
              placeholder: 'podling'
            _ '-'
            _input.name.list name: 'suffix1', required: true, 
              placeholder: 'list', pattern: '^\w+(-\w+)?$'
            _ '@'
            _input.name.subdomain disabled: true, value: 'incubator'
            _ '.'
            _input.name name: 'domain', value: 'apache.org', disabled: true
          end
        else
          _legend 'ASF Mailing List Request'

          _h3_ 'List name'
          _input.name name: 'localpart', required: true, pattern: '^\w+$',
            placeholder: 'name'
          _ '@'
          _select name: 'subdomain' do
            pmcs.sort.each do |pmc|
              _option pmc unless pmc == 'incubator'
            end
          end
          _ '.'
          _input.name name: 'domain', value: 'apache.org', disabled: true
        end

        _h3_ 'Replies'
        _label title: 'if set, will replies will go to the same list. ' +
          'Except for commits, which will direct replies to the dev list.' do
          _input type: 'checkbox', name: 'replyto', value: 'true'
          _ 'Set Reply-To list header?'
        end

        _h3_ 'Moderation'
        _label do
          _input type: "radio", name: "muopts", value: "mu", required: true
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
        
        _h3_ 'Moderators'
        _textarea.mods! name: 'mods'

        _h3_ 'Commit message'
        _textarea name: 'message', cols: 70

        _input type: 'submit', value: 'Submit Request'
      end
    end

    if _.post?
      Dir.chdir '/var/tools/infra/mlreq'
      _.system 'svn update --non-interactive'

      # extract moderators from input fields or text area
      mods = params.select {|name,value| name =~ /^mod\d+$/ and value != ['']}.
        values.flatten.join(',')
      mods = @mods.gsub(/\s+/,',') if @mods

      # build a queue of requests
      queue = []

      if @localpart
        queue << {
          localpart: @localpart,
          subdomain: @subdomain,
          domain: @domain || 'apache.org',
          moderators: mods,
          muopts: @muopts,
          replytolist: @replyto || "false",
          notifyee: "private@#{@subdomain}.apache.org"
        }
      else
        params.keys.grep(/^suffix\d+/).each do |suffix|
          suffix = params[suffix].first
          next if suffix.empty?
          queue << {
            localpart: "#{@podling}-#{suffix}",
            subdomain: 'incubator',
            domain: @domain || 'apache.org',
            moderators: mods,
            muopts: @muopts,
            replytolist: @replyto || "false",
            notifyee: "private@incubator.apache.org"
          }
        end
      end

      # build a list of validation errors
      errors = []

      checks = {
        localpart: /^\w+(-\w+)*$/,
        subdomain: /^\w+$/,
        domain: /^apache[.]org$/,
        muopts: /^(mu|Mu|mU)$/,
        replytolist: /^(true|false)$/,
        notifyee: /^\w+[@]\w+[.]apache[.]org$/
      }

      queue.each do |vars|
        checks.each do |name, pattern|
          if vars[name] !~ pattern
            errors << "Invalid #{name}: #{vars[name].inspect}"
          end

          vars[:moderators].split(',').each do |email|
            begin
              if email != Mail::Address.new(email).address
                errors << "Invalid email: #{email.inspect}"
              end
            rescue
              errors << "Invalid email: #{email.inspect}"
            end
          end

          unless pmcs.include? @subdomain
            errors << "Invalid pmc: #{@subdomain}"
          end
        end

        mlreq = "#{vars[:subdomain]}-#{vars[:localpart]}".gsub(/[^-\w]/,'_')
        if File.exist? "#{mlreq.untaint}.txt"
          errors << "Already submitted: " +
            "#{vars[:localpart]}@#{vars[:subdomain]}.#{vars[:domain]}"
        end
      end

      # output requests or errors
      if errors.empty?
        _h2_ "Submitted request(s)"
        queue.each do |vars|
          mlreq = "#{vars[:subdomain]}-#{vars[:localpart]}".gsub(/[^-\w]/,'_')
          vars.each {|name,value| vars[name] = Shellwords.shellescape(value)}
          request = vars.map {|name,value| "#{name}=#{value}\n"}.join
          _pre request
          File.open("#{mlreq.untaint}.txt",'w') { |file| file.write request }
          _.system(['svn', 'add', '--', "#{mlreq.untaint}.txt"])
        end

        @message =
          "#{vars[:localpart]}@#{vars[:subdomain]} request by #{$USER}:\n" .
	  @message
        _.system [
	  'svn', 'commit', '-m', @message, '--no-auth-cache',
	  '--non-interactive',
	  (['--username', $USER, '--password', $PASSWORD] if $PASSWORD),
	  '--', "#{mlreq.untaint}.txt",
        ]
      else
        _h2_ 'Form not submitted due to errors'
        _ul do
          errors.each { |error| _li error }
        end
      end
    else
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
    
    _script_ %{
      // replace moderator textarea with two input fields
      $('#mods').replaceWith('<input type="email" required="required" ' +
        'class="mod" name="mod0" placeholder="email"/>')
      $('.mod:last').after('<input type="email" required="required" ' +
        'class="mod" name="mod1" placeholder="email"/>')

      // initially disable suffix (until podling is entered)
      $('input[name=suffix1]').attr('disabled', true);

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
          var div = $(this).parent().clone();
          var input = $('input:not(:disabled)', div);
          input.attr('name', 'suffix' + ($('div.list').length+1)).val('').
            attr('required', false).bind('input', pkeyup);
          lastpod.unbind().parent().after(div);
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
    if not lists.any? {|list| list.start_with? "incubator-#{@podling}-"}
      _confirm "Podling #{@podling} not found.  Treat as new?"
      next _focus 'input[name=podling]'
    end
  end

  # confirm if pmc is unknown
  if @subdomain != @confirmed_localpart
    validated['confirmed_localpart'] = @subdomain
    if not ASF::Committee.list.map(&:name).include? @subdomain
      _confirm "PMC #{@subdomain} not found.  Treat as new?"
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
