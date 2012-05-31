#!/usr/bin/ruby1.9.1
require 'wunderbar'
require 'shellwords'

_html do
  _head_ do
    _title 'ASF Mailing List Request'
    _script src: '/jquery-min.js'
    _style %{
      textarea, .mod, label {display: block}
      input[type=submit] {display: block; margin-top: 1em}
      legend {background: #141; color: #DFD; padding: 0.4em}
      .name {width: 6em}
    }
  end

  _body? do
    _form method: 'post' do
      _fieldset do
        _legend 'ASF Mailing List Request'

        _h3_ 'List name'
        _input.name name: 'subdomain', required: true, pattern: '^\w+$',
          placeholder: 'name'
        _ '@'
        _input.name name: 'localpart', required: true, pattern: '^\w+$',
          placeholder: 'pmc'
        _ '.'
        _input.name name: 'domain', value: 'apache.org', readonly: true

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

      vars = {
        subdomain: @subdomain,
        localpart: @localpart,
        domain: @domain,
        moderators: mods,
        muopts: @muopts,
        replytolist: @replyto || "false",
        notifyee: "#{$USER}@apache.org"
      }

      _h2 'What would be submitted'
      _pre vars.map {|name,value| "#{name}=#{Shellwords.shellescape value}"}.
        join("\n")
    else
      _p do
        _ "Looking to create a Incubator mailing list?  Try"
        _a "ASF Incubator Mailing List Request", href: 'incmlreq'
        _ 'instead.'
      end
    end
    
    _script_ %{
      $('textarea').replaceWith('<input type="email" required="required" ' +
        'class="mod" name="mod0" placeholder="email"/>')

      var fkeyup = function() {
        if ($(this).val() != '') {
          var input = $('<input type="email" class="mod" val=""/>');
          input.attr('name', 'mod' + $('.mod').length);
          input.bind('keyup paste', fkeyup);
          lastmod.after(input).unbind();
          lastmod = input;
        }
      }
      var lastmod = $('.mod:last');
      $('.mod').bind('keyup paste', fkeyup);
    }
  end
end
