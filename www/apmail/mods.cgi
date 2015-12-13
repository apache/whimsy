#!/usr/bin/ruby1.9.1
require 'shellwords'
require 'whimsy/asf'

# TODO: determine apmail@hermes,wheel@hermes gorup membership
unless apmail.include? $USER or wheel.include? $USER
  pmc = ENV['PATH_INFO'][/\/([-\w]+)\.apache\.org\//,1]
  pmc &&= ASF::Committee.find(pmc)
  user = ASF::Person.find($USER)
  unless pmc and pmc.members.include? user
    print "Status: 401 Unauthorized\r\n"
    if pmc and not pmc.members.empty?
      print "WWW-Authenticate: Basic realm=\"#{pmc.display_name} PMC\"\r\n\r\n"
    else
      print "WWW-Authenticate: Basic realm=\"APMail\"\r\n\r\n"
    end
    exit
  end
end

mods = JSON.load(File.read('/home/apmail/subscriptions/mods'))

_html do
  _head_ do
    _title 'ASF Mailing List Moderator administration'
    _script src: '/jquery-min.js'
    _style %{
      table {border-spacing: 1em 0.2em }
      thead th {border-bottom: solid black}
      tbody tr:hover {background-color: #FF8}
      label {display: block}
      .message {border: 1px solid #0F0; background-color: #CFC}
      .warn {border: 1px solid #F00; background-color: #FCC}
      .demo {border: 1px solid #F80; background-color: #FC0}
      .message, .warn, .demo {padding: 0.5em; border-radius: 1em}
    }
  end

  _body? do
    # common banner
    _a href: 'https://whimsy.apache.org/' do
      _img title: "Logo", alt: "Logo", 
        src: "https://id.apache.org/img/asf_logo_wide.png"
    end

    _h2.demo "*** Demo mode - Changes aren't saved ***"
    _h1_ 'ASF Moderator administration'

    if ENV['PATH_INFO'] == '/'

      _h2_ 'Domains'
      _ul do
        _li! { _a 'apache.org', href: "apache.org/" }
        _li! { _a 'apachecon.com', href: "apachecon.com/" }
      end
      _ul do
        mods.keys.sort.each do |domain|
          next if %w(apache.org apachecon.com).include? domain
          _li! { _a domain.split('.').first, href: "#{domain}/" }
        end
      end

    elsif ENV['PATH_INFO'] == '/list'

      _h2 "ASF Mailing List moderators" 
      emails = [] 
      mods.each do |domain, lists| 
        lists.each do |list, moderators| 
          emails += moderators.map(&:downcase) 
        end 
      end 
 
      _ul do 
        emails.uniq.sort.each do |email| 
          _li! { _a email, href: email } 
        end 
      end 

    elsif ENV['PATH_INFO'] =~ %r{@}

      email = env['PATH_INFO'][1..-1].downcase
      _h2 "Lists moderated by #{email}" 
      _ul do 
        mods.each do |domain, lists| 
          lists.each do |list, moderators| 
            if moderators.map(&:downcase).include? email 
              _li! do
                _a "#{list}@#{domain}", href: "#{domain}/#{list}/"
              end
            end 
          end 
        end 
      end 

    elsif ENV['PATH_INFO'] =~ %r{^/([-.\w]*apache\w*\.\w+)/$}

      _h2_ "Mailing Lists - #{$1}"
      stem = "#{$1}-"
      _ul do
        mods[$1].keys.each do |list|
          _li! { _a list, href: "#{list}/" }
        end
      end

    elsif ENV['PATH_INFO'] =~ %r{^/([-.\w]*apache\w*\.\w+)/([-\w]+)/$}

      domain, list = $1, $2

      dir = "/home/apmail/lists/#{domain}/#{list}"

      if _.post? and @email.to_s.include? '@'
        if %w(sub unsub).include? @op
          person = ASF::Person.find_by_email(@email)
          op = (@op == 'sub' ? 'added' : 'removed')
          mods[domain][list] << @email if @op == 'sub'
          mods[domain][list].delete @email if @op == 'unsub'
          if person
            _p.message "#{person.public_name} was #{op} as a moderator."
          else
            _p.message "#{@email} was #{op} as a moderator."
          end
        end
      end

      apmail_bin = ASF::SVN['infra/infrastructure/apmail/trunk/bin']
      archives = File.read(File.join(apmail_bin, '.archives'))
      archives = Hash[*JSON.parse('['+archives.sub(/,?\s*\Z/,']'))]

      pmc = domain.split('.').first
      listname = "#{pmc}-#{list}"
      href = 
        if archives[listname]
          if archives[listname].include? '/apmail/public-arch/'
            "http://mail-archives.apache.org/mod_mbox/#{listname}"
          else
            user = ASF::Person.find($USER)
            if user.asf_member?
              "https://mail-search.apache.org/members/private-arch/#{listname}"
            elsif ASF::Committee.find(pmc).members.include? user
              "https://mail-search.apache.org/pmc/private-arch/#{listname}"
            end
          end
        end
  
      if href
        _h2_ {_a "#{list}@#{domain}", href: href}
      else
        _h2_ "#{list}@#{domain}"
      end

      _table_ do
        _thead_ do
          _tr do
            _th 'Email'
            _th 'Name'
          end
        end
        _tbody do
          mods[domain][list].sort.each do |email|
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
              disabled: (mods[domain][list].length <= 2)
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
          var spinner = $('<img src="/spinner.gif"/>');
          $('input[name=email]').after(spinner);
          $.post('', $('form').serialize(), function(_) {
            if (confirm(_.prompt)) {
              confirmed = true;
              $('form').submit();
            }
            spinner.remove();
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
