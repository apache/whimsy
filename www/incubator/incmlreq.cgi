#!/usr/bin/ruby1.9.1
require 'wunderbar'
require 'shellwords'

_html do
  _head_ do
    _title 'ASF Incubator Mailing List Request'
    _script src: '/jquery-min.js'
    _style %{
      textarea, .mod, label {display: block}
      input[type=submit] {display: block; margin-top: 1em}
      legend {background: #141; color: #DFD; padding: 0.4em}
      .name {width: 6em}
      input:disabled {color: #000}
    }
  end

  _body? do
    _form method: 'post' do
      _fieldset do
        _legend 'ASF Incubator Mailing List Request'

        _h3_ 'Podling name'
        _input.name name: 'podling', required: true, pattern: '^\w+$',
          placeholder: 'name'

        _h3_ 'List name'
        _div.list do
          _input.name.podling disabled: true, value: '<podling>', 
            placeholder: 'podling'
          _ '-'
          _input.name name: 'suffix1', required: true, placeholder: 'list',
            pattern: '^\w+(-\w+)?$'
          _ '@'
          _input.name.localpart disabled: true, value: 'incubator'
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
        _textarea name: 'mods'

        _input type: 'submit', value: 'Submit Request'
      end
    end

    if _.post?
      mods = params.select {|name,value| name =~ /^mod\d+$/ and value != ['']}.
        values.flatten.join(',')
      mods = @mods.gsub(/\s+/,',') if @mods

      _h2 'What would be submitted'
      params.keys.grep(/^suffix\d+/).each do |suffix|
        suffix = params[suffix].first
        next if suffix.empty?
        vars = {
          subdomain: "#{@podling}-#{suffix}",
          localpart: 'incubator',
          domain: 'apache.org',
          moderators: mods,
          muopts: @muopts,
          replytolist: @replyto || "false",
          notifyee: "#{$USER}@apache.org"
        }

        _pre vars.map {|name,value| "#{name}=#{Shellwords.shellescape value}"}.
          join("\n")
      end
    else
      _p do
        _ "Looking to create a non-Incubator mailing list?  Try"
        _a "ASF Mailing List Request", href: 'asfmlreq'
        _ 'instead.'
      end
    end
    
    _script_ %{
      $('textarea').replaceWith('<input type="email" required="required" ' +
        'class="mod" name="mod0" placeholder="email"/>')

      var mkeyup = function() {
        if ($(this).val() != '') {
          var input = $('<input type="email" class="mod" val=""/>');
          input.attr('name', 'mod' + $('.mod').length);
          input.bind('keyup paste', mkeyup);
          lastmod.after(input).unbind();
          lastmod = input;
        }
      }

      var pkeyup = function() {
        if ($(this).val() != '') {
          var div = $(this).parent().clone();
          var input = $('input:not(:disabled)', div);
          input.attr('name', 'suffix' + ($('.list').length+1)).val('').
            attr('required', false).bind('keyup paste', pkeyup);
          lastpod.unbind().parent().after(div);
          lastpod = input;
        }
      }

      var lastmod = $('.mod:last');
      var lastpod = $('.list:last input[required]');
      lastmod.bind('keyup paste', mkeyup);
      lastpod.bind('keyup paste', pkeyup);

      $('.podling').val($('input[name=podling]').val());
      $('input[name=podling]').bind('keyup paste', function() {
        $('input.podling').val($(this).val());
      });
    }
  end
end
