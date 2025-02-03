#!/usr/bin/env ruby
PAGETITLE = "Member Meeting Proxy Selection Form" # Wvisible:meeting
$LOAD_PATH.unshift '/srv/whimsy/lib'

require 'whimsy/asf'
require 'wunderbar'
require 'wunderbar/bootstrap'
require 'wunderbar/jquery'
require 'date'
require 'tmpdir'
require 'whimsy/asf/meeting-util'

# Emit basic instructions and details on quorum
def emit_instructions(today, cur_mtg_dir, meeting)
  meeting_display = meeting.gsub(%r{\A(\d\d\d\d)(\d\d)(\d\d)\z}, "\\1-\\2-\\3")
  if today > meeting
    _p.text_warning %{
        WARNING: Data for the next Member's Meeting is not yet available,
        so this form will not work yet.  Please wait until the Board Chair
        announces the opening of nominations for the board and new members,
        and then check back to assign a new proxy for the meeting.
        Data from the previous meeting on #{meeting_display} is shown below for debugging only.
      }
  end
  _p %{
    This form allows you to assign a proxy for the upcoming
    Member's Meeting on #{meeting_display}.  Submitting an attendance proxy will
    help us reach quorum at the start of the meeting - the meeting can't formally
    continue without quorum at the start.

    You can still vote and attend the meeting if you want, and you can revoke a
    proxy at any time.
  }
  _p %{
    If you submit a proxy, you will still be sent ballots by email to your personal
    @apache.org email address one week ahead of the meeting.
    
    If you won't have internet access for the full week of the meeting, ask
    for how to assign a proxy for your vote ballots as well.
  }
  _p do
    _ 'Note while the legal proxy form below states your proxy may have your voting rights, in practice '
    _strong 'you will still be emailed your ballots'
    _ ' unless you explicitly mark a \'*\' in the appropriate place in the '
    _code 'proxies'
    _ ' file.  The great majority of proxies assigned are for attendance only; not for voting.'
  end
  num_members, quorum_need, num_proxies, attend_irc = ASF::MeetingUtil.calculate_quorum(cur_mtg_dir)
  if num_members
    _p do
      _ 'Currently, we must have '
      _span.text_primary attend_irc
      _ " Members attend the #{meeting_display} meeting and respond to Roll Call to reach quorum and continue the meeting."
      _ " Calculation: Total voting members: #{num_members}, with one third for quorum: #{quorum_need}, minus previously submitted proxies: #{num_proxies}"
    end
  end
end

# Emit meeting data and form for user to select a proxy - GET
def emit_form(cur_mtg_dir, meeting, volunteers, disabled)
  if disabled
    _h3 'No upcoming meeting'
    _p 'There is currently no meeting scheduled. Call back later.'
    return
  end
  begin
    secretary_id = ASF::Committee.officer('secretary').id
  rescue StandardError
    secretary_id = ''
  end

  help, copypasta = ASF::MeetingUtil.is_user_proxied(cur_mtg_dir, $USER)
  user_is_proxy = help && copypasta
  _whimsy_panel(user_is_proxy ? "You Are Proxying For Others" : "Select A Proxy For Upcoming Meeting", style: 'panel-success') do
    _div do
      if help
        _p help
        if copypasta
          _ul.bg_success do
            copypasta.each do |copyline|
              _pre copyline
            end
          end
        end
      else
        _p 'The following members have explicitly volunteered to serve as proxies; select any one of them, or select any other member that you know will proxy for you (or ask!):'
        _ul do
          volunteers.each do |vol|
            _pre vol
          end
        end
      end
    end

    if user_is_proxy
      _p.text_warning %{
          NOTE: you are proxying for other members, so you cannot assign
          someone else to proxy for your attendance.  If it turns out that
          you will not be able to attend the IRC meeting on Thursday,
          you MUST work with the Board Chair and your proxies to update the
          proxy records, and get someone else to mark their presence!
        }
    else
      _div.well.well_lg do
        _form method: 'POST', onsubmit: 'return validateForm();' do
          _div.form_group do
            _label 'Select proxy'
            _b do
              _p %{
                WARNING: If you select someone other than the Chair or Secretary (*), please note
                that your proxy will not be counted if the person is unable to attend.              }
            end
            _p %{
              (* The meeting will be postponed if the Chair and/or Secretary cannot attend)
            }


            # Fetch LDAP
            ldap_members = ASF.members
            ASF::Person.preload('cn', ldap_members)

            # Fetch members.txt
            members_txt = ASF::Member.list

            # get a list of members who have submitted proxies
            exclude = Dir[File.join(cur_mtg_dir,'proxies-received', '*')].
              map {|name| name[/(\w+)\.\w+$/, 1]}

            _select.combobox.input_large.form_control name: 'proxy' do
              if meeting != '20220615'
                _option 'Select an ASF Member', :selected, value: ''
              end
              # Allow for missing public name (should not happen unless LDAP is inconsistent)
              ldap_members.sort_by{|m| m.public_name || '_'}.each do |member|
                next if member.id == $USER               # No self proxies
                next if exclude.include? member.id       # Not attending
                next unless members_txt[member.id]       # Non-members
                next if members_txt[member.id]['status'] # Emeritus/Deceased
                # Display the availid to users to match volunteers array above
                _option "#{member.public_name || '?No public name?'} (#{member.id})",
                  selected: (member.id == secretary_id)
              end
            end
          end
          _div_.form_group do
            _p do
              _b 'Note that you cannot select a member who has nominated a proxy'
            end
            _p do
              _ "IMPORTANT! Be sure to tell the person that you select as proxy above that you've assigned them to mark your attendance! They simply need to mark your proxy attendance when the meeting starts."
              _a 'Read full procedures for Member Meeting', href: 'https://www.apache.org/foundation/governance/members.html#meetings'
            end
            _div.button_group.text_center do
              _button.btn.btn_primary 'Submit'
            end
          end
        end
        _pre IO.read(File.join(cur_mtg_dir, 'member_proxy.txt'))
      end
    end
  end

  _script src: "js/bootstrap-combobox.js" # TODO do we need this still?

  _script_ %{
    function validateForm() {
      if ($('.combobox').val() == '')  {
        alert("A proxy name is required");
        return false;
      }
      return true;
    }

    // convert select into combobox
    $('.combobox').combobox();

    // disable submit until a value is selected
    if ($('.combobox').val() == '') $('.btn').prop('disabled', true);

    // enable submit when proxy is chosen
    $('*[name="proxy"]').change(function() {
      $('.btn').prop('disabled', false);
      });
  }
end

# Emit a record of a user's submission - POST
def emit_post(cur_mtg_dir, meeting, _)
  # Detect missing/invalid proxy info (should not happen)
  raise ArgumentError,"Invalid proxy name '#{@proxy}'" unless @proxy =~ %r{\A.+ \([a-z0-9-]+\)\z}

  _h3_ 'Proxy Assignment - Session Transcript'

  # collect data
  proxy = File.read(File.join(cur_mtg_dir, 'member_proxy.txt'))
  user = ASF::Person.find($USER)
  date = Date.today.strftime("%B %-d, %Y")

  # update proxy form (match as many _ as possible up to the name length)
  proxy[/authorize _(_{,#{@proxy.length}})/, 1] = @proxy.gsub(' ', '_')

  proxy[/signature: _(_#{'_' * user.public_name.length}_)/, 1] =
    "/#{user.public_name.gsub(' ', '_')}/"

  proxy[/name: _(#{'_' * user.public_name.length})/, 1] =
    user.public_name.gsub(' ', '_')

  proxy[/availid: _(#{'_' * user.id.length})/, 1] =
    user.id.gsub(' ', '_')

  proxy[/Date: _(#{'_' * date.length})/, 1] = date.gsub(' ', '_')

  proxyform = proxy

  # report on commit
  _div.transcript do
    Dir.mktmpdir do |tmpdir|
      svn =  ASF::SVN.getInfoItem(File.join(MEETINGS,meeting),'url')

      ASF::SVN.svn_('checkout',[svn, tmpdir], _,
                    {quiet: true, user: $USER, password: $PASSWORD})
      Dir.chdir(tmpdir) do
        # write proxy form
        filename = "proxies-received/#{$USER}.txt"
        update_existing_form = File.exist? filename
        File.write(filename, proxyform)
        unless update_existing_form
          ASF::SVN.svn_('add', filename, _)
          ASF::SVN.svn_('propset', ['svn:mime-type', 'text/plain; charset=utf-8', filename], _)
        end

        # get a list of proxies
        list = Dir['proxies-received/*.txt'].map do |file|
          form = File.read(file)

          id = File.basename(file, '.txt') # assume filename is a valid id
          proxy = form[/hereby authorize ([\S].*) to act/, 1].
            gsub('_', ' ').strip
          # Ensure availid is not included in proxy name here
          proxy.sub!(%r{\([^)]+\)}, '')
          proxy.strip!
          name = form[/signature: ([\S].*)/, 1].gsub(/[\/_]/, ' ').strip

          "   #{proxy.ljust(24)} #{name} (#{id})"
        end

        # gather a list of all non-text proxies (TODO unused)
        nontext = Dir['proxies-received/*'].
          reject {|file| file.end_with? '.txt'}.
          map {|file| file[/([-A-Za-z0-9]+)\.\w+$/, 1]}

        # update proxies file
        proxies = IO.read('proxies')
        # look for lines containing '(id)' which start with 3 spaces
        # TODO this assumes that the volunteer lines start with 2 spaces
        existing = proxies.scan(/   \S.*\(\S+\).*$/)
        # extract the ids
        existing_ids = existing.map {|line| line[/\((\S+)\)/, 1] }
        # ensure this id is not treated as previously existing
        if existing_ids.delete(user.id)
          existing.reject! {|line| line[/\((\S+)\)$/, 1] == user.id}
        end
        # keep only new ids
        added = list.
          reject {|line| existing_ids.include? line[/\((\S+)\)$/, 1]}
        list = added + existing
        # look for the last '-' at the end of a line.
        # This should be under the 'For:' column heading just before the proxies
        # TODO it would be safer to look for <name>
        proxies[/.*-\n(.*)/m, 1] = list.flatten.sort.join("\n") + "\n"

        IO.write('proxies', proxies)

        # commit
        ASF::SVN.svn_('commit',[filename, 'proxies'], _,
          {msg: "assign #{@proxy} as my proxy", user: $USER, password: $PASSWORD})
# TODO: send email to @proxy per WHIMSY-78
      end
    end
  end

  # Report on contents now that they're checked in
  _h3! do
    _span "Contents of "
    _code "foundation/Meetings/#{meeting}/#{$USER}.txt"
    _span " as now checked in to svn:"
  end
  _pre proxyform
end

# produce HTML
_html do
  _style :system
  _style %{
    .transcript {margin: 0 16px}
    .transcript pre {border: none; line-height: 0}
  }
  _body? do
    # Find latest meeting and check if it's in the future yet
    MEETINGS = ASF::SVN['Meetings']
    cur_mtg_dir = ASF::MeetingUtil.get_latest(MEETINGS)
    meeting = File.basename(cur_mtg_dir)
    today = Date.today.strftime('%Y%m%d')
    _whimsy_body(
      title: PAGETITLE,
      style: (today > meeting ? 'panel-danger' : 'panel-info'),
      subtitle: today > meeting ? "ERROR: Next Meeting Data Not Available" : "How To Assign A Proxy For Upcoming Meeting",
      related: {
        '/members/meeting' => 'How-To / FAQ for Member Meetings',
        '/members/attendance-xcheck' => 'Members Meeting Attendance Crosscheck',
        '/members/inactive' => 'Inactive Member Feedback Form',
        '/members/subscriptions' => 'Members@ Mailing List Crosscheck'
      },
      helpblock: -> {
        emit_instructions(today, cur_mtg_dir, meeting)
      }
    ) do
      if _.get?
        emit_form(cur_mtg_dir, meeting, ASF::MeetingUtil::getVolunteers(cur_mtg_dir), today > meeting)
      else # POST
        # WHIMSY-409: improve UI
        begin
          emit_post(cur_mtg_dir, meeting, _)
        rescue ArgumentError => e
          _h2_.text_danger {_span.label.label_danger e}
        end
      end
    end
  end
end

