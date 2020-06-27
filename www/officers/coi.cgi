#!/usr/bin/env ruby
PAGETITLE = "Conflict of Interest Affirmations"
$LOAD_PATH.unshift '/srv/whimsy/lib'
require 'wunderbar'
require 'wunderbar/bootstrap'
require 'whimsy/asf'
require 'mail'
require 'date'
require 'tmpdir'

coi_url = ASF::SVN.svnurl('conflict-of-interest')
YEAR = DateTime.now.strftime "%Y"
COI_CURRENT_URL = File.join(coi_url, YEAR).untaint
COI_CURRENT_TEMPLATE_URL = File.join(COI_CURRENT_URL, 'template.txt')

user = ASF::Person.find($USER)
USERID = user.id
USERNAME = user.cn.untaint
USERMAIL = "#{USERID}@apache.org".untaint
committees = ASF::Committee.officers + ASF::Committee.nonpmcs
chairs = committees.map do |committee|
 committee.chairs.map {|chair| chair[:id]}
end
IDS = (chairs.flatten + ASF::Service['board'].members.map(&:id)).uniq

# Get the list of files in this year's directory
signerfileslist, err = ASF::SVN.svn('list', COI_CURRENT_URL, {user: $USER.dup.untaint, password: $PASSWORD.dup.untaint})
# Currently the documents directory has limited access.
# This includes ASF members, but does not include officers who are not members
# Let others down gently
unless signerfileslist
  Wunderbar.warn err
  print "Status: 404 Not found\r\n\r\n" # TODO better status
  print "Sorry, cannot access COI documents\r\n"
  exit
end
signerfiles = signerfileslist.split("\n")

# Create the hash of {signer: signerurl} and remember user's affirmation file
SIGNERS = Hash.new
user_affirmation_file = nil
signerfiles.each do |signerfile|
  stem = File.basename(signerfile, ".*")
  user_affirmation_file = signerfile if stem == USERID
  SIGNERS[stem] = signerfile unless stem == 'template'
end
USER_AFFIRMATION_FILE = user_affirmation_file

# Determine if user should sign the affirmation form
user_is_required = IDS.include? USERID
not_required_message = user_is_required ?' required':' not required'
user_affirmation = SIGNERS.include? USERID
have_affirmed_message = user_affirmation ? ' have affirmed' : ' have not affirmed'
USER_IS_REQUIRED_BUT_NOT_AFFIRMED = (user_is_required and not user_affirmation)
current_timestamp = DateTime.now.strftime "%Y-%m-%d %H:%M:%S"
PANEL_MESSAGE = USER_IS_REQUIRED_BUT_NOT_AFFIRMED ?
  'Sign Your Conflict of Interest Affirmation':
  'Thank you for signing the Conflict of Interest Affirmation'

# Read the template and append the signature block
def get_affirmed_template(name, timestamp)
  signature_block =
  '       I, the undersigned, acknowledge that I have received,
         read and understood the Conflict of Interest policy;
         I agree to comply with the policy;
         I understand that ASF is charitable and in order to maintain
         its federal tax exemption it must engage primarily in activities
         which accomplish one or more of its tax-exempt purposes.
       Signed: __
       Date: __
       Metadata: _______________Whimsy www/officers/coi.cgi________________'
  template, err =
    ASF::SVN.svn('cat', COI_CURRENT_TEMPLATE_URL, {user: $USER.dup.untaint, password: $PASSWORD.dup.untaint})
  raise RuntimeError.new("Failed to read current template.txt -- %s" % err) unless template
  centered_name = "#{name}".center(60, '_')
  centered_date ="#{timestamp}".center(62, '_')
  filled_signature_block = signature_block
    .gsub('Signed: __', ('Signed: ' + centered_name))
    .gsub('Date: __'  , (  'Date: ' + centered_date))
  template + filled_signature_block
end

_html do
  _body? do
    _whimsy_body(
    title: PAGETITLE,
    related: {
      'http://www.apache.org/foundation/records/minutes/2020/board_minutes_2020_03_18.txt'  =>
        'Conflict of Interest Resolution Board minutes',
      COI_CURRENT_TEMPLATE_URL => 'Conflict of Interest Resolution',
      COI_CURRENT_URL => "#{YEAR} affirmations",
    },
    helpblock: -> {
      _p do
        _b 'DRAFT DRAFT DRAFT - Feedback is solicited at dev@whimsical.apache.org'
        _p
        _ 'This page allows officers to sign their Conflict of Interest annual affirmation.'
      end
      if _.get?
        _p 'The following are currently required to affirm the Conflict of Interest:'
        _table.table.table_striped do
          _thead do
            _tr do
              _th 'Name'
              _th 'AvailId'
              _th 'Link to affirmation(s)'
            end
          end
          _tbody do
            IDS.each do |id|
              affirmer = ASF::Person.find(id)
              _tr do
                _td affirmer.cn
                _td affirmer.id 
                _td do
                  signerfile = SIGNERS[affirmer.id]
                  if signerfile
                    _a affirmer.id, href: "#{COI_CURRENT_URL}/#{signerfile}"
                  else
                    _ "Not signed in #{YEAR}"
                  end
                end
              end
            end
          end
        end
        _p
        _p "You are signed in as #{USERNAME} (#{USERID}) at #{current_timestamp}."
        _p {_ "You are ";_b "#{not_required_message}";_ " to affirm the Conflict of Interest policy for this year."}
        _p {_ "You ";_b "#{have_affirmed_message}";_  "the Conflict of Interest policy for this year."}
        if  USER_AFFIRMATION_FILE
          _a "Your Conflict of Interest affirmation",
            href: "#{COI_CURRENT_URL}/#{USER_AFFIRMATION_FILE}"
        end
        if USER_IS_REQUIRED_BUT_NOT_AFFIRMED
          _p {_b "You are invited to sign the affirmation below"}
        end
      end
    }
    ) do
      if _.get?
        if USER_IS_REQUIRED_BUT_NOT_AFFIRMED
          _whimsy_panel(PANEL_MESSAGE, style: 'panel-success') do
            affirmed = get_affirmed_template(USERNAME,  current_timestamp)

            _pre affirmed

            _b 'This is a DRAFT for feedback; pressing the button will send email to you but will not register your affirmation'

            _form.form_horizontal method: 'post' do
              _div.form_group do
                _div.col_sm_offset_1.col_sm_10 do
                  _input.btn.btn_default type: 'submit',
                    value: 'Sign your Conflict of Interest Affirmation'
                end
              end
            end
          end
        end
      else # POST
        _whimsy_panel('Sign Conflict of Interest Affirmation - Session Transcript',
            style: 'panel-success') do
          _div.transcript do
            emit_post(_)
          end
        end
      end
    end
  end
end

# Emit a record of a user's submission - POST
def emit_post(_)
  # The only information in the POST is $USER and $PASSWORD
  current_timestamp = DateTime.now.strftime "%Y-%m-%d %H:%M:%S"

  affirmed = get_affirmed_template(USERNAME, current_timestamp)
  user_filename = "#{USERID}.txt".untaint

  # report on commit
  _div.transcript do
    Dir.mktmpdir do |tmpdir|
      ASF::SVN.svn_!('checkout',[COI_CURRENT_URL, tmpdir.untaint], _,
                    {args: '--quiet', user: $USER.dup.untaint, password: $PASSWORD.dup.untaint})
      Dir.chdir(tmpdir) do
        # write affirmation form
        File.write(user_filename, affirmed)
        ASF::SVN.svn_!('add', user_filename, _)
        ASF::SVN.svn_!('propset', ['svn:mime-type', 'text/plain; charset=utf-8', user_filename], _)

        # commit
        # TODO enable commit of affirmation
#        ASF::SVN.svn_!('commit',[user_filename], _,
#         {msg: "Affirm Conflict of Interest Policy for #{USERNAME}",
#           user: $USER.dup.untaint, password: $PASSWORD.dup.untaint})
      end
    end
    # Send email to $USER, secretary@
    ASF::Mail.configure
    mail = Mail.new do
      to "#{USERNAME}<#{USERMAIL}>"
      # TODO enable cc: secretary
 #     cc "secretary@apache.org"
      from "#{USERMAIL}"
      subject "Conflict of Interest affirmation from #{USERNAME}"
      text_part do
        body "
DRAFT DRAFT DRAFT Please review this; nothing has been checked in.
Send feedback to dev@whimsical.apache.org
This year's Conflict of Interest affirmation is attached.
It has been checked into the foundation repository at
#{COI_CURRENT_URL}/#{user_filename}.\n
Regards,\n
#{USERNAME}\n\n"
      end
    end
    mail.attachments["#{USERID}.txt"] = affirmed
    mail.deliver!
  end

  # Report on contents now that they're checked in
  _h3! do
    _span "You can review "
    _a "Your Conflict of Interest affirmation",
      href: "#{COI_CURRENT_URL}/#{$USER}.txt"
    _span " as now checked in to svn."
    _p {_ "Reload ";_a "this page",href: "coi.cgi";_span " to see the results."}
  end
end

