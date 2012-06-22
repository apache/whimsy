#!/usr/bin/ruby1.9.1
require 'shellwords'
require '/var/tools/asf'

# from hermes
wheel = %w(joes pgollucci pctony pquerna norman gmcdonald markt arreyder)
apmail = %w(gmcdonald joes pgollucci pctony pquerna norman pctony gstein noel
  coar dims geirm brett lars rubys craigmcc dirkx upayavira mbenson smtpd
  arreyder clr)

unless apmail.include? $USER or wheel.include? $USER
  print "Status: 401 Unauthorized\r\n"
  print "WWW-Authenticate: Basic realm=\"APMail\"\r\n\r\n"
  exit
end

_html do
  _head_ do
    _title 'ASF Mailing List Moderator administration'
    _script src: '/jquery-min.js'
    _style %{
      table {border-spacing: 1em 0.2em }
      thead th {border-bottom: solid black}
      tbody tr:hover {background-color: #FF8}
      label {display: block}
      .message {padding: 0.5em; border: 1px solid #0F0; background-color: #CFC}
      .warn {padding: 0.5em; border: 1px solid #F00; background-color: #FCC}
    }
  end

  _body do
    # common banner
    _a href: 'https://id.apache.org/' do
      _img title: "Logo", alt: "Logo", 
        src: "https://id.apache.org/img/asf_logo_wide.png"
    end

    _h1_ 'ASF Mailing List Moderator administration'

    if ENV['PATH_INFO'] == '/'

      _h2_ 'PMCs'
      lists = ASF::Mail.lists
      stems = lists.map {|name| name.split('-').first}.uniq
      _ul do
        stems.sort.each do |stem|
          _li! { _a stem, href: "#{stem}/" }
        end
      end

    elsif ENV['PATH_INFO'] == '/incubator/'

      _h2_ 'Podlings'
      lists = ASF::Mail.lists.select {|list| list.start_with? 'incubator-'}
      stems = lists.map {|name| name.split('-')[1]}.uniq
      _ul do
        stems.sort.each do |stem|
          if lists.include? "incubator-#{stem}"
            _li! { _a stem, href: "#{stem}/" }
          else
            _li! { _a stem, href: "../incubator-#{stem}/" }
          end
        end
      end

    elsif ENV['PATH_INFO'] =~ %r{^/((incubator-)?\w+)/$}

      _h2_ "Mailing Lists - #{$1}"
      stem = "#{$1}-"
      _ul do
        ASF::Mail.lists.sort.each do |list|
          next unless list.start_with? stem
          list = list.sub(stem,'')
          _li! { _a list, href: "#{list}/" }
        end
      end

    elsif ENV['PATH_INFO'] =~ %r{^/(incubator-)?(\w+)/(\w+)/$}

      if $1
        pmc = 'incubator'
        list = "#{$2}-#{$3}"
      else
        pmc, list = $2, $3
      end
      dir = "/home/apmail/lists/#{pmc}.apache.org/#{list}"

      if _.post? and @email.to_s.include? '@'
        if %w(sub unsub).include? @op
          person = ASF::Person.find_by_email(@email)
          output = apmailcmd("ezmlm-#{@op}", dir, 'mod', @email)
          if output.chomp != ''
            _pre.warn output
          else
            op = (@op == 'sub' ? 'added' : 'removed')
            if person
              _p.message "#{person.public_name} was #{op} as a moderator."
            else
              _p.message "#{@email} was #{op} as a moderator."
            end
          end
        end
      end

      _h2_ "Moderators - #{pmc}-#{list}"
      mods = apmailcmd('ezmlm-list', dir, 'mod')
      _table_ do
        _thead_ do
          _tr do
            _th 'Email'
            _th 'Name'
          end
        end
        _tbody do
          mods.lines.sort.each do |email|
            person = ASF::Person.find_by_email(email.chomp)
            _tr_ do
              _td email.chomp
              _td! do
                if person
                  href = "/roster/committer/#{person.id}"
                  if person.asf_member?
                    _strong { _a person.public_name, href: href }
                  else
                    _a person.public_name, href: href
                  end
                else
                  _em 'unknown'
                end
              end
            end
          end
        end

        if mods == ''
          _tr do
            _td(colspan: 2) {_em 'none'}
          end
        end
      end

      _h2 'Action'
      _form_ method: 'post' do
        _div style: 'float: left' do
          _label do
            _input type: 'radio', name: 'op', value: 'sub', required: true,
              checked: true
            _ 'Add'
          end
          _label do
            _input type: 'radio', name: 'op', value: 'unsub', 
              disabled: (mods.lines.count <= 2)
            _ 'Remove'
          end
        end
        _input type: 'email', name: 'email', placeholder: 'email',
          required: true, style: 'margin-left: 1em; margin-top: 0.5em'
      end

      _script %{
        // Make click select the email to be removed
        $('tbody tr').click(function() {
          $('input[name=email]').val($('td:first', this).text()).focus();
          $('input:enabled[value=unsub]').prop('checked', true);
        });

        // Confirmation dialog
        var confirmed = false;
        $('form').submit(function() {
          if (confirmed) return true;
          $.post('', $('form').serialize(), function(_) {
            if (confirm(_.prompt)) {
              confirmed = true;
              $('form').submit();
            }
          }, 'json');
          return false;
        });
      }
    end
  end
end

_json do
  person = ASF::Person.find_by_email(@email)
  if @op == 'unsub'
    if person
      _prompt "Remove #{person.public_name} as a moderator?"
    else
      _prompt "Remove #{@email} as a moderator?"
    end
  else
    if person
      _prompt "Add #{person.public_name} as a moderator?"
    else
      _prompt "Unknown email.  Add #{@email} as a moderator anyway?"
    end
  end
end

def apmailcmd *cmd
  cmd = Shellwords.escape(Shellwords.join(cmd)).untaint
  cmd = Shellwords.join(['bash','-c', cmd])
  `ssh -t hermes.apache.org sudo -u apmail #{cmd}`
end
