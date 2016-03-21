#!/usr/bin/env ruby
$LOAD_PATH.unshift File.realpath(File.expand_path('../../../lib', __FILE__))

require 'wunderbar'
require 'whimsy/asf'
require 'date'
require 'tmpdir'

# Update ~/.whimsy to have a :svn: entry for the following:
MEETINGS = ASF::SVN['private/foundation/Meetings']

_html do
  _link href: "css/bootstrap.min.css", rel: 'stylesheet'
  _link href: "css/bootstrap-combobox.css", rel: 'stylesheet'
  _style :system
  _style %{
    .transcript {margin: 0 16px}
    .transcript pre {border: none; line-height: 0}
  }

  meeting = File.basename(Dir["#{MEETINGS}/2*"].sort.last).untaint

  # get a list of members who have submitted proxies
  exclude = Dir["#{MEETINGS}/#{meeting}/proxies-received/*"].
    map {|name| name[/(\w+)\.\w+$/, 1]}

  if _.get?

    _div_.container do
      _div.row do
        _div.well.text_center do
          _h1 'ASF Proxy Selection Form'
          _h3 Date.parse(meeting).strftime("%B %-d, %Y")
        end
      end

      _div.row do
        _div do
          _p %{
            This form allows you to assign a proxy for the upcoming members
            meeting. By default it will assume you intend to assign the proxy
            for the meeting only, and you will still be sent voting ballots by
            email. If you do not have internet access during the meeting
            window and would like to assign the member to vote for you, please
            select a proxy below.
          }
        end
      end

      _div.row do
        _div do
          _pre IO.read("#{MEETINGS}/#{meeting}/member_proxy.txt")
        end
      end

      _form method: 'POST' do
        _div_.row do
          _div.form_group do
            _label 'Select proxy'

            # Fetch LDAP
            ldap_members = ASF.members
            ASF::Person.preload('cn', ldap_members)

            # Fetch members.txt
            members_txt = ASF::Member.list

            _select.combobox.input_large.form_control name: 'proxy' do
              _option 'Select an ASF Member', :selected, value: ''
              ldap_members.sort_by(&:public_name).each do |member|
                next if member.id == $USER               # No self proxies
                next if exclude.include? member.id       # Not attending
                next unless members_txt[member.id]       # Non-members
                next if members_txt[member.id]['status'] # Emeritus/Deceased
                _option member.public_name
              end
            end
          end
        end

        _div_.row do
          _div.button_group.text_center do
            _button.btn.btn_primary 'Submit'
          end
        end
      end
    end

    _script src: "js/jquery-1.11.1.min.js"
    _script src: "js/bootstrap.min.js"
    _script src: "js/bootstrap-combobox.js"

    _script_ %{
      // convert select into combobox
      $('.combobox').combobox();

      // initially disable submit
      $('.btn').prop('disabled', true);

      // enable submit when proxy is chosen
      $('*[name="proxy"]').change(function() {
        $('.btn').prop('disabled', false);
      });
    }

  else
    _body? do
      _h3_ 'Session Transcript'

      # collect data
      proxy = File.read("#{MEETINGS}/#{meeting}/member_proxy.txt")
      user = ASF::Person.find($USER)
      date = Date.today.strftime("%B %-d, %Y")

      # update proxy form
      proxy[/authorize _(#{'_' *@proxy.length})/, 1] = @proxy.gsub(' ', '_')

      proxy[/signature: _(_#{'_' *user.public_name.length}_)/, 1] = 
        "/#{user.public_name.gsub(' ', '_')}/"

      proxy[/name: _(#{'_' *user.public_name.length})/, 1] = 
        user.public_name.gsub(' ', '_')

      proxy[/Date: _(#{'_' *date.length})/, 1] = date.gsub(' ', '_')

      proxyform = proxy.untaint

      # report on commit
      _div.transcript do
        Dir.mktmpdir do |tmpdir|
          svn = `svn info #{MEETINGS}/#{meeting}`[/URL: (.*)/, 1]

          _.system [
            'svn', 'checkout', '--quiet', svn.untaint, tmpdir.untaint,
            ['--no-auth-cache', '--non-interactive'],
            (['--username', $USER, '--password', $PASSWORD] if $PASSWORD)
          ]

          Dir.chdir(tmpdir) do
            # write proxy form
            filename = "proxies-received/#$USER.txt".untaint
            File.write(filename, proxyform)
            _.system ['svn', 'add', filename]

            # get a list of proxies
            list = Dir['proxies-received/*.txt'].map do |file|
              form = File.read(file.untaint)
        
              id = file[/([-A-Za-z0-9]+)\.\w+$/, 1]
              proxy = form[/hereby authorize ([\S].*) to act/, 1].
                gsub('_', ' ').strip
              name = form[/signature: ([\S].*)/, 1].gsub(/[\/_]/, ' ').strip

              "   #{proxy.ljust(24)} #{name} (#{id})"
            end
    
            # gather a list of all non-text proxies (TODO unused)
            nontext = Dir['proxies-received/*'].
              reject {|file| file.end_with? '.txt'}.
              map {|file| file[/([-A-Za-z0-9]+)\.\w+$/, 1]}

            # update proxies file
            proxies = IO.read('proxies')
            existing = proxies.scan(/   \S.*\(\S+\).*$/)
            existing_ids = existing.map {|line| line[/\((\S+)\)/, 1] }
            added = list.
              reject {|line| existing_ids.include? line[/\((\S+)\)$/, 1]}
            list = added + existing
            proxies[/.*-\n(.*)/m, 1] = list.flatten.sort.join("\n") + "\n"

            IO.write('proxies', proxies)

            # commit
            _.system [
              'svn', 'commit', filename, 'proxies',
              '-m', "assign #{@proxy} as my proxy",
              ['--no-auth-cache', '--non-interactive'],
              (['--username', $USER, '--password', $PASSWORD] if $PASSWORD)
            ]
          end
        end
      end

      # report on contents
      _h3! do
        _span "Contents of "
        _code "foundation/meetings/#{meeting}/#{$USER}.txt"
        _span ":"
      end

      _pre proxyform
    end
  end
end
