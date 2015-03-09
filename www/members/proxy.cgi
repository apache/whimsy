#!/usr/bin/ruby1.9.1
require 'wunderbar'
require 'whimsy/asf'
require 'date'

# Update ~/.whimsy to have a :svn: entry for the following:
MEETINGS = ASF::SVN['private/foundation/Meetings']

_html do
  _link href: "css/bootstrap.min.css", rel: 'stylesheet'
  _link href: "css/bootstrap-combobox.css", rel: 'stylesheet'
  _style :system

  meeting = File.basename(Dir["#{MEETINGS}/2*"].sort.last).untaint

  if _.get?

    _div_.container do
      _div.row do
        _div.well.text_center do
          _h1 'ASF Proxy Selection Form'
          _h3 Date.parse(meeting).strftime("%B %-d, %Y")
        end
      end

      _form method: 'POST' do
        _div_.row do
          _div.form_group do
            _label 'Select proxy'

            members = ASF.members
            ASF::Person.preload('cn', members)

            _select.combobox.input_large.form_control name: 'proxy' do
              _option 'Select an ASF Member', :selected, value: ''
              members.sort_by(&:public_name).each do |member|
                next if member.id == $USER
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

    # report on commit
    _h3 'Commit Log'
    Dir.chdir("#{MEETINGS}/#{meeting}/proxies-received") do
      _.system ['svn', 'cleanup']
      _.system ['svn', 'up']

      filename = "#$USER.txt".untaint
      File.write(filename, proxy.untaint)
      _.system ['svn', 'add', filename]

      # commit
      _.system [
        'svn', 'commit', '-m', "assign #{@proxy} as my proxy", filename,
        ['--no-auth-cache', '--non-interactive'],
        (['--username', $USER, '--password', $PASSWORD] if $PASSWORD)
      ]
    end

    # report on contents
    _h3! do
      _span "Contents of "
      _code "foundation/meetings/#{meeting}/#{$USER}.txt"
      _span ":"
    end

    _pre proxy
  end
end
