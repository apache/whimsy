#!/usr/bin/env ruby
$LOAD_PATH.unshift File.realpath(File.expand_path('../../../lib', __FILE__))

require 'wunderbar'
require 'whimsy/asf'
require 'date'
require 'tmpdir'

MEETINGS = ASF::SVN['private/foundation/Meetings']
meeting = File.basename(Dir["#{MEETINGS}/2*"].sort.last).untaint

# Calculate how many members required to attend first half for quorum
def calculate_quorum(meeting)
  begin
    num_members = File.read("#{MEETINGS}/#{meeting}/record").each_line.count
    quorum_need = num_members / 3
    num_proxies = Dir["#{MEETINGS}/#{meeting}/proxies-received/*"].count
    attend_irc = quorum_need - num_proxies
  rescue StandardError => e
    # Ensure we can't break rest of script
    puts "ERROR: #{e}"
    return 0, 0, 0, 0
  end
  return num_members, quorum_need, num_proxies, attend_irc
end

# Get info about current users's proxying
# @return "help text", ["id | name (proxy)", ...] if they are a proxy
# @return "You have already submitted a proxy form"
# @return nil otherwise
def is_user_proxied(meeting, id)
  user = ASF::Person.find(id)
  lines = IO.read("#{MEETINGS}/#{meeting}/proxies")
  proxylist = lines.scan(/\s\s(.{25})(.*?)\((.*?)\)/) # [["Shane Curcuru    ", "David Fisher ", "wave"], ...]
  help = nil
  copypasta = [] # theiravailid | Their Name in Rolls (proxy)
  proxylist.each do |arr|
    if user.cn == arr[0].strip
      copypasta << "#{arr[2].ljust(12)} | #{arr[1].strip} (proxy)"
    elsif user.id == arr[2]
      help = "NOTE: You appear to have already submitted a proxy form for someone else to mark your attendance! "
    end
  end
  if copypasta.empty?
    return help
  else
    (help ||= "") << "Since you are a proxy for others, then AFTER the 2. Roll Call is called, you may copy/paste the below lines to mark your and your proxies attendance."
    copypasta.unshift("#{user.id.ljust(12)} | #{user.cn}")
    return help, copypasta
  end
end

_html do
  _link href: "css/bootstrap.min.css", rel: 'stylesheet'
  _link href: "css/bootstrap-combobox.css", rel: 'stylesheet'
  _style :system
  _style %{
    .transcript {margin: 0 16px}
    .transcript pre {border: none; line-height: 0}
  }


  # get a list of members who have submitted proxies
  exclude = Dir["#{MEETINGS}/#{meeting}/proxies-received/*"].
    map {|name| name[/(\w+)\.\w+$/, 1]}

  if _.get?

    _div_.container do
      _div.row do
        _div.well.text_center do
          _h1 'Member Meeting Proxy Selection Form'
          _h3 Date.parse(meeting).strftime("%B %-d, %Y")
        end
      end

      _div.row do
        _div do
          _p %{
            This form allows you to assign an attendance proxy for the upcoming 
            Member's Meeting. If there is any chance you might not be able 
            to attend the first part of the Member's Meeting on Tuesday, then 
            please assign a proxy, because that helps the meeting reach 
            quorum more quickly. 
            You can still attend the meeting if you want, and can revoke a 
            proxy at any time.
          }
          _p %{
            You will still be sent board and new member ballots by email 
            during the meeting's 46 hour recess (between Tuesday and Thursday, 
            with two hours for vote counting), so you will still need to 
            cast your votes by checking your mail during the recess. If 
            you won't have internet access the week of the meeting, ask 
            for how to assign a proxy for your vote ballots as well.
          }
          num_members, quorum_need, num_proxies, attend_irc = calculate_quorum(meeting)
          if num_members
            _p do
              _ 'Currently, we must have '
              _span.text_primary "#{attend_irc}" 
              _ ' Members attend the first half of the meeting and respond to Roll Call to reach quorum and continue the meeting.'
              _ " Calculation: Total voting members: #{num_members}, with one third for quorum: #{quorum_need}, minus previously submitted proxies: #{num_proxies}"
            end
          end
          _p %{
            IMPORTANT! Be sure to tell the person that you select as proxy 
            that you've assigned them to mark your attendance! They simply 
            need to mark your proxy attendance when the meeting starts.
          }
          help, copypasta = is_user_proxied(meeting, $USER)
          if help
            _p help
            if copypasta
              _ul do
                copypasta.each do |copyline|
                  _pre copyline
                end
              end
            end
          end
          _a 'Read full procedures for Member Meeting', href: 'https://www.apache.org/foundation/governance/members.html#meetings'
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
      _h3_ 'Proxy Assignment - Session Transcript'

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
            _.system ['svn', 'propset', 'svn:mime-type',
              'text/plain; charset=utf-8', filename]

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
