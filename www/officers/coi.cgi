#!/usr/bin/env ruby
PAGETITLE = "Conflict of Interest"
$LOAD_PATH.unshift '/srv/whimsy/lib'
require 'wunderbar'
require 'wunderbar/bootstrap'
require 'whimsy/asf'
require 'mail'
require 'date'
require 'tmpdir'

coi_url = ASF::SVN.svnurl('conflict-of-interest')
YEAR = DateTime.now.strftime "%Y"
coi_current_url = File.join(coi_url, YEAR)
coi_current_template_url = File.join(coi_current_url, 'template.txt')

user = ASF::Person.find($USER)
committees = ASF::Committee.officers + ASF::Committee.nonpmcs
chairs = committees.map do |committee|
 committee.chairs.map {|chair| chair[:id]}
end
ids = (chairs.flatten + ASF::Service['board'].members.map(&:id)).uniq

# Get the list of files in this year's directory
signerfileslist, err = ASF::SVN.svn('list', coi_current_url, {user: $USER, password: $PASSWORD})
#signerfileslist = 'template.txt\nclr99.jpg\nfielding33.pdf\ncurcuru20.jpg'
signerfiles = signerfileslist.split('\n')
signers = []
# Get the url for the user's affirmation
user_affirmation_file = nil
signerfiles.each do |signerfile|
  stem = signerfile[0..signerfile.index(".")-1]
  user_affirmation_file = signerfile if stem == user.id
  signers.push stem unless stem == 'template'
end
# Get the list of required users who have not yet signed
nonsigners = []
ids.each do |required|
  nonsigners.push(required) unless signers.include? required
end

# Decide if user should sign the affirmation form
user_is_required = ids.include? user.id
not_required_message = user_is_required ?' required':' not required'
user_affirmation = signers.include? user.id
have_affirmed_message = user_affirmation ? ' have affirmed' : ' have not affirmed'
user_is_required_but_not_affirmed = (user_is_required and not user_affirmation)
current_timestamp = DateTime.now.strftime "%Y-%m-%d %H:%M:%S"
panel_message = user_is_required_but_not_affirmed ? 'Register Your Conflict of Interest  Affirmation':'Thank you for signing the Conflict of Interest Affirmation'

# Read the template and append the signature block
def get_affirmed_template(url, user, password, name, timestamp)
  signature_block =
  "I, the undersigned, acknowledge that I have received,\n
  read and understood the Conflict of Interest policy;\n
  I agree to comply with the policy;\n
  I understand that ASF is charitable and in order to maintain\n
  its federal tax exemption it must engage primarily in activities\n
  which accomplish one or more of its tax-exempt purposes.\n
  Signed: __\n
  Date: __\n
  Metadata: __________Whimsy coi.cgi___________\n"
  template, err =
    ASF::SVN.svn('cat', url, {user: user, password: password})
  affirmed = (template + signature_block)
    .gsub("Signed: __", "Signed: __________#{name}___________")
    .gsub("Date: __",   "  Date: __________#{timestamp}______")
end

_html do
  _body? do
    _whimsy_body(
    title: PAGETITLE,
    related: {
    'http://www.apache.org/foundation/records/minutes/2020/board_minutes_2020_03_18.txt'  => 'Conflict of Interest Resolution Board minutes',
    coi_current_template_url => 'Conflict of Interest Resolution',
    },
    helpblock: -> {
      _p do
        _ 'This page allows officers to register their Conflict of Interest annual affirmation.'
      end
      if _.get?
      _p 'The following are currently required to affirm the Conflict of Interest:'
      ids.each do |id|
       affirmer = ASF::Person.find(id)
       _ "#{affirmer.cn} (#{affirmer.id}) "
      end
      _p
      _p "You are signed in as #{user.cn} (#{user.id}) at #{current_timestamp}."
      _p {_ "You are ";_b "#{not_required_message}";_ " to affirm the Conflict of Interest policy for this year."}
      _p {_ "You ";_b "#{have_affirmed_message}";_  "the Conflict of Interest policy for this year."}
      _p 'Signers for this year:'
      signers.each do |signer|
        _ signer
      end
      _p 'Nonsigners for this year:'
      nonsigners.each do |nonsigner|
        _ nonsigner
      end
      _p
      if  user_affirmation_file
        _a "Your Conflict of Interest affirmation",
          href: "#{coi_current_url}/#{user_affirmation_file}"
      end
      if user_is_required_but_not_affirmed
        _p {_b "You are invited to sign the affirmation below"}
      end
      end
    }
    ) do
        if _.get?
          if user_is_required_but_not_affirmed
            _whimsy_panel(panel_message, style: 'panel-success') do
              affirmed = get_affirmed_template(coi_current_template_url, $USER, $PASSWORD, user.cn,  current_timestamp)
              affirmed.each_line do |line|
                _p line
              end
              _form.form_horizontal method: 'post' do
                _div.form_group do
                  _div.col_sm_offset_2.col_sm_10 do
                    _input.btn.btn_default type: 'submit', value: 'Affirm Conflict of Interest policy'
                  end
                end
              end
            end
          end
        else # POST
          _whimsy_panel('About to commit your affirmation...', style: 'panel-success') do
            _div.transcript do
              _h3_ 'Affirm transcript'
              emit_post(_)
            end
          end
        end
#      end
    end
  end
end

# Emit a record of a user's submission - POST
def emit_post(_)
  _h3_ 'Affirm Conflict of Interest - Session Transcript'

  # collect data
  user = ASF::Person.find($USER)
  current_timestamp = DateTime.now.strftime "%Y-%m-%d %H:%M:%S"
  affirmed = get_affirmed_template(coi_current_template_url, $USER, $PASSWORD, user.cn, current_timestamp)
  user_filename = "#{user.id}.txt"

  # report on commit
  _div.transcript do
    Dir.mktmpdir do |tmpdir|
      svn =  ASF::SVN.getInfoItem(coi_current_url,'url')

      ASF::SVN.svn_('checkout',[svn.untaint, tmpdir.untaint], _,
                    {args: '--quiet', user: $USER, password: $PASSWORD})
      Dir.chdir(tmpdir) do
        # write affirmation form
        filename = user_filename.untaint
        File.write(filename, affirmed)
        ASF::SVN.svn_('add', filename, _)
        ASF::SVN.svn_('propset', ['svn:mime-type', 'text/plain; charset=utf-8', filename], _)

        # commit
#        ASF::SVN.svn_('commit',[filename], _,
 #         {msg: "Affirm Conflict of Interest Policy for #{$USER}", user: $USER, password: $PASSWORD})
# TODO: send email to @proxy per WHIMSY-78
      end
    end
  end

  # Report on contents now that they're checked in
  _h3! do
    _span "You can review "
    _a "Your Conflict of Interest affirmation",
      href: "#{coi_current_url}/#{$USER}.txt}"
    _span " as now checked in to svn."
  end
#  _pre proxyform
end

