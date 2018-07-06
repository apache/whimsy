class Invite < Vue
  def initialize
    @disabled = true
    @alert = nil

    # initialize form fields
    @iclaname = ''
    @iclaemail = ''
    @pmc = ''
    @votelink = ''
    @noticelink = ''
    @phase = ''
    @role = ''
    @roleText = ' to submit ICLA for '
    @subject = ''
    @subjectPhase = ''
    @previewMessage = 'Preview'
    @pmcOrPpmc = ''
    @phasePrefix = ''
    @member = Server.data.member
    @user = Server.data.user

# initialize conditional text
    @showPMCVoteLink = false;
    @showPPMCVoteLink = false;
    @voteErrorMessage = '';
    @showVoteErrorMessage = false;
    @showPMCNoticeLink = false;
    @showPPMCNoticeLink = false;
    @noticeErrorMessage = '';
    @showNoticeErrorMessage = false;
    @showDiscussFrame = false;
    @showVoteFrame = false;
    @showPhaseFrame = false;
    @showRoleFrame = false;
    @discussComment = ''
    @voteComment = ''
    @proposalText = ''
    @voteProposalText = ''
  end

  def render
    _p %{
      This application allows PMC and PPMC members to
      discuss contributors to achieve consensus;
      vote on contributors to become a committer or a PMC/PPMC member; or
      simply invite them to submit an ICLA.
    }
    _p do
      _b '** NOTE: only new contributors are currently supported, i.e. existing ASF committers are excluded. **'
    end
    _p %{
      If you would like to discuss the candidate, go to the Discuss tab
      after filling the contributor and PMC/PPMC fields.
    }
    _p %{
      If you have discussed the candidate and would like to conduct a vote,
      go to the Vote tab after filling the contributor and PMC/PPMC fields.
    }
    _p %{
      If you have already achieved consensus, you can go to the Invite tab
      after filling the contributor and PMC/PPMC fields.
    }


    # error messages
    if @alert
      _div.alert.alert_danger do
        _b 'Error: '
        _span @alert
      end
    end

    #
    # Form fields
    #

    _div.form_group do
      _label "Contributor's name (required):", :for => 'iclaname'
      _input.form_control.iclaname! placeholder: 'GivenName FamilyName',
        required: true, value: @iclaname
    end
    _div.form_group do
      _label "Contributor's E-Mail address (required):", :for => 'iclaemail'
      _input.form_control.iclaemail! type: 'email', required: true,
        placeholder: 'user@example.com', onChange: self.setIclaEmail,
        value: @iclaemail
    end

    _div.form_group do
      _label "PMC/PPMC (required)", :for => 'pmc'
      _select.form_control.pmc! required: true, onChange: self.setPMC, value: @pmc do
        _option ''
        Server.data.allData.each_key do |pmc|
          _option pmc if Server.data.allData[pmc]['pmc']
        end
        _option '---', disabled: true # No point letting it be chosen
        Server.data.allData.each_key do |ppmc|
          _option ppmc unless Server.data.allData[ppmc]['pmc']
        end
      end
    end
    if @showPhaseFrame
      _ul.nav.nav_tabs do
        _li :class => ('active' if @phase == :discuss) do
          _a 'Discuss', onClick: self.selectDiscuss
        end
        _li :class => ('active' if @phase == :vote) do
          _a 'Vote', onClick: self.selectVote
        end
        _li :class => ('active' if @phase == :invite) do
          _a 'Invite', onClick: self.selectInvite
        end
      end
    end
    if @showPMCVoteLink
      _p %{
        Fill the following field only if the person was voted by the PMC
        to become a committer.
        Link to the [RESULT][VOTE] message in the mail archives.
      }
    end
    if @showPPMCVoteLink
      _p %{
        Fill the following field only if the person is an initial
        committer on a new project accepted for incubation, or the person
        has been voted as a committer on a podling.
        For new incubator projects use the
        http://wiki.apache.org/incubator/XXXProposal link; for existing
        podlings link to the [RESULT][VOTE] message in the mail archives.
      }
    end
    if @showPMCVoteLink or @showPPMCVoteLink
      _ 'Navigate to '
      _a "Ponymail", href: "https://lists.apache.org/list.html?private@#{@mail_list}.apache.org:lte=1M:[VOTE][RESULT]", target: _blank
      _ ', select the appropriate message, right-click PermaLink, copy link'
      _ ' to the clip-board, and paste the link here.'
      _p

      _div.form_group do
        _label "VOTE link", :for => 'votelink'
        _input.form_control.votelink! type: 'url', onChange: self.setVoteLink,
        value: @votelink
      end
      if @showVoteErrorMessage
        _div.alert.alert_danger do
          _span @voteErrorMessage
        end
      end
    end
    if @showPMCNoticeLink
      _p %{
        Fill the following field only if the person was voted by the PMC
        to become a PMC member.
        Link to the [NOTICE] message sent to the board.
        The message must have been in the archives for at least 72 hours.
      }
    end
    if @showPPMCNoticeLink
      _p %{
        Fill the following field only if the person was voted by the
        PPMC to be a PPMC member.
        Link to the [NOTICE] message sent to the incubator PMC.
        The message must have been in the archives for at least 72 hours.
      }
    end
    if @showPMCNoticeLink or @showPPMCNoticeLink
      _ 'Navigate to '
      if @showPMCNoticeLink
        _a "Ponymail", href: "https://lists.apache.org/list.html?board@apache.org:lte=1M:NOTICE%20for%20#{@display_name}", target: _blank
      else
        _a "Ponymail", href: "https://lists.apache.org/list.html?private@incubator.apache.org:lte=1M:NOTICE%20for%20#{@display_name}", target: _blank
      end
      _ ', select the appropriate message, right-click PermaLink, copy link'
      _ ' to the clip-board, and paste the link here.'
      _p

      _div.form_group do
        _label "NOTICE link", :for => 'noticelink'
        _input.form_control.noticelink! type: 'url', onChange: self.setNoticeLink,
        value: @noticelink
      end
    end
    if @showNoticeErrorMessage
      _div.alert.alert_danger do
        _span @noticeErrorMessage
      end
    end
    if @showRoleFrame
      _div.form_check do
        _label do
          _input type: :radio, name: :role, value: :committer, id: 'role_committer',
          onClick: lambda {@role = :committer;
            @disabled = false
            @subject = @subjectPhase + ' Invite ' + @iclaname +
              ' to become a committer for ' + @display_name
            @proposalText = 'I propose we invite ' + @iclaname +
              ' to become a committer.'
            @voteProposalText = @proposalText + "\nHere is my +1."
          }
          _span @phasePrefix +
            ' invite to become a committer'
        end
        _br
        _label do
          _input type: :radio, name: :role, value: :pmc, id: 'role_pmc',
          onClick: lambda {@role = :pmc
            @disabled = false
            @subject = @subjectPhase + ' Invite ' + @iclaname +
              ' to become committer and ' + @pmcOrPPMC + ' member for ' + @display_name
            @proposalText = 'I propose we invite ' + @iclaname +
              ' to become a committer and ' + @pmcOrPPMC + ' member.'
            @voteProposalText = @proposalText + ' Here is my +1.'
          }
          _span @phasePrefix +
            ' invite to become a committer and ' + @pmcOrPPMC + ' member'
        end
        if @showDiscussFrame
          _br
          _label do
            _input type: :radio, name: :role, value: :invite, id: 'role_invite',
            onClick: lambda {@role = :invite
              @disabled = false
              @subject = @subjectPhase + ' Invite ' + @iclaname +
              ' to submit an ICLA for ' + @display_name
              @proposalText = 'I propose we invite ' + @iclaname +
                ' to submit an ICLA.'
            }
            _span @phasePrefix +
              ' invite to submit an ICLA'
          end
        end
        _p
      end
    end
    if @showDiscussFrame
      _div 'From: ' + @member
      _div 'To: private@' + @mail_list + '.apache.org'
      _div 'Subject: ' + @subject
      _p
      _span @proposalText
      _p
      _textarea.form_control rows: 4,
        placeholder: 'Here are my reasons:',
        name: 'discussComment', value: @discussComment,
        onChange: self.setdiscussComment
    end
    if @showVoteFrame
      _div 'From: ' + @member
      _div 'To: private@' + @mail_list + '.apache.org'
      _div 'Subject: ' + @subject
      _p
      _span @voteProposalText
      _p
      _textarea.form_control rows: 4,
      placeholder: 'Here are my reasons:',
      name: 'voteComment', value: @voteComment,
      onChange: self.setvoteComment
    end

    #
    # Submission buttons
    #
    _p do
      _button.btn.btn_primary @previewMessage, disabled: @disabled,
      onClick: self.preview
    end
    #
    # Hidden form: preview invite email
    #
    _div.modal.fade.invitation_preview! do
      _div.modal_dialog do
        _div.modal_content do
          _div.modal_header do
            _button.close "\u00d7", type: 'button', data_dismiss: 'modal'
            _h4 'Preview Invitation Email'
          end

          _div.modal_body do
            # headers
            _div do
              _b 'From: '
              _span @userEmail
            end
            _div do
              _b 'To: '
              _span "#{@iclaname} <#{@iclaemail}>"
            end
            _div do
              _b 'cc: '
              _span @pmcEmail
            end

            # draft invitation email
            _div.form_group do
              _label :for => 'invitation'
              _textarea.form_control.invitation! value: @invitation, rows: 12,
                onChange: self.setInvitation
            end
          end

          _div.modal_footer do
            _button.btn.btn_default 'Cancel', data_dismiss: 'modal'
            _button.btn.btn_primary 'Mock Send', onClick: self.mockSend
          end
        end
      end
    end
    _p

    #
    # Hidden form: preview discussion email
    #
    _div.modal.fade.discussion_preview! do
      _div.modal_dialog do
        _div.modal_content do
          _div.modal_header do
            _button.close "\u00d7", type: 'button', data_dismiss: 'modal'
            _h4 'Discussion Email'
          end

          _div.modal_body do
            # headers
            _div do _b 'From: '
              _span @member
            end
            _div do _b 'To: '
              _span @pmcEmail
            end
            _div do _b 'Subject: '
              _span @subject
            end
            _div do _b
              _pre @message
            end
          end

          _div.modal_footer do
            _button.btn.btn_default 'Close', data_dismiss: 'modal'
          end
        end
      end
    end
    _p

    #
    # Hidden form: preview vote email
    #
    _div.modal.fade.vote_preview! do
      _div.modal_dialog do
        _div.modal_content do
          _div.modal_header do
            _button.close "\u00d7", type: 'button', data_dismiss: 'modal'
            _h4 'Vote Email'
          end

          _div.modal_body do
            # headers
            _div do _b 'From: '
              _span @member
            end
            _div do _b 'To: '
              _span @pmcEmail
            end
            _div do _b 'Subject: '
              _span @subject
            end
            _div do _b
              _pre @message
            end
          end

          _div.modal_footer do
            _button.btn.btn_default 'Close', data_dismiss: 'modal'
          end
        end
      end
    end
    _p

  end
  # when the form is initially loaded, set the focus on the iclaname field
  def mounted()
    document.getElementById('iclaname').focus()
  end

  #
  # field setters
  #

  def resetCheckBoxes()
    document.getElementById('role_pmc').checked = false if document.getElementById('role_pmc')
    document.getElementById('role_committer').checked = false if document.getElementById('role_committer')
    document.getElementById('role_invite').checked = false if document.getElementById('role_invite')
  end

def setIclaName(event)
    @iclaname = event.target.value
    self.checkValidity()
  end

  def setIclaEmail(event)
    @iclaemail = event.target.value
    self.checkValidity()
  end

  def setPMC(event)
    @pmc = event.target.value
    if Server.data.allData[@pmc]
      @isPMC = Server.data.allData[@pmc]['pmc']
      @pmcOrPPMC = @isPMC ? 'PMC' : 'PPMC'
      @phase = :discuss
      @subject = ''
      @showPhaseFrame = true
      @showRoleFrame = true
      @mail_list = Server.data.allData[@pmc]['mail_list']
      @display_name = Server.data.allData[@pmc]['display_name']
    else
      @isPMC = false # true, but not the whole story!
      @pmcOrPPMC = '---'
      @phase = :discuss
      @subject = ''
      @showPhaseFrame = false
      @showRoleFrame = false
      @mail_list = '---'
      @display_name = '---'
    end
    self.checkValidity()
    selectDiscuss()
  end

  def selectDiscuss(event)
    @phase = :discuss
    @subject = ''
    @subjectPhase = '[DISCUSS]'
    @previewMessage = 'Start the Discussion'
    @phasePrefix = ' Start the discussion to'
    @showDiscussFrame = true;
    @showRoleFrame = true;
    @showVoteFrame = false;
    @showPMCVoteLink = false
    @showPPMCVoteLink = false
    @showPMCNoticeLink = false
    @showPPMCNoticeLink = false
    @showVoteErrorMessage = false;
    @showNoticeErrorMessage = false;
    self.checkValidity()
    @disabled = true;
    self.resetCheckBoxes()
  end

  def setdiscussComment(event)
    @discussComment = event.target.value
  end

  def selectVote(event)
    @phase = :vote
    @subject = ''
    @subjectPhase = '[VOTE]'
    @previewMessage = 'Start the Vote'
    @phasePrefix = ' Start the vote to'
    @showVoteFrame = true;
    @showRoleFrame = true;
    @showDiscussFrame = false;
    @showPMCVoteLink = false
    @showPPMCVoteLink = false
    @showPMCNoticeLink = false
    @showPPMCNoticeLink = false
    @showVoteErrorMessage = false;
    @showNoticeErrorMessage = false;
    self.checkValidity()
    @disabled = true;
    self.resetCheckBoxes()
  end

  def setvoteComment(event)
    @voteComment = event.target.value
  end

  def selectInvite(event)
    @phase = :invite
    @previewMessage = 'Preview Invitation'
    @showDiscussFrame = false;
    @showVoteFrame = false;
    @showRoleFrame = false;
    @showPMCVoteLink = @isPMC
    @showPPMCVoteLink = ! @isPMC
    @showPMCNoticeLink = @isPMC
    @showPPMCNoticeLink = ! @isPMC
    @showVoteErrorMessage = false;
    @showNoticeErrorMessage = false;
    checkVoteLink() if document.getElementById('votelink');
    checkNoticeLink() if document.getElementById('noticelink');
    self.checkValidity()
  end

  def setVoteLink(event)
    @votelink = event.target.value
    @showVoteErrorMessage = false
    checkVoteLink()
    self.checkValidity()
  end

  def checkVoteLink()
    document.getElementById('votelink').setCustomValidity('');
    if (@votelink)
      # verify that the link refers to lists.apache.org message on the project list
      if not @votelink=~ /^https:\/\/lists\.apache\.org\//
        @voteErrorMessage = "Error: Please link to\
        a message via https://lists.apache.org/"
        @showVoteErrorMessage = true;
      end
      if not @votelink=~ /private@#{@mail_list}(\.incubator)?\.apache\.org/
        @voteErrorMessage = "Error: Please link to\
        the [RESULT][VOTE] message sent to the private list."
        @showVoteErrorMessage = true;
      end
      if @showVoteErrorMessage
        document.getElementById('votelink').setCustomValidity(@voteErrorMessage);
      end
    end
  end

  def setNoticeLink(event)
    @noticelink = event.target.value
    @showNoticeErrorMessage = false;
    checkNoticeLink()
    self.checkValidity()
  end

  def checkNoticeLink()
    document.getElementById('noticelink').setCustomValidity('');
    # verify that the link refers to lists.apache.org message on the proper list
    if (@noticelink)
      if not @noticelink=~ /^https:\/\/lists\.apache\.org\//
        @noticeErrorMessage = "Error: please link to\
        a message via https://lists.apache.org/"
        @showNoticeErrorMessage = true;
      end
      if @showPMCNoticeLink and not @noticelink=~ /board@apache\.org/
        @noticeErrorMessage = "Error: please link to\
        the NOTICE message sent to the board list."
        @showNoticeErrorMessage = true;
      end
      if @showPPMCNoticeLink and not @noticelink=~ /private@incubator\.apache\.org/
        @noticeErrorMessage = "Error: please link to\
        the NOTICE message sent to the incubator private list."
        @showNoticeErrorMessage = true;
      end
      if @showNoticeErrorMessage
        document.getElementById('noticelink').setCustomValidity(@noticeErrorMessage);
      end
    end
  end

  def setInvitation(event)
    @invitation = event.target.value
    self.checkValidity()
  end

  #
  # validation and processing
  #

  # client side field validations
  def checkValidity()
    @disabled = !%w(iclaname iclaemail pmc votelink noticelink).all? do |id|
      element = document.getElementById(id)
      (not element) or element.checkValidity()
    end
  end

  # server side field validations
  def preview()
    if @phase == :invite
      previewInvitation()
    elsif @phase == :discuss
      previewDiscussion()
    elsif @phase == :vote
      previewVote()
    end
  end

  def previewInvitation()
    data = {
      iclaname: @iclaname,
      iclaemail: @iclaemail,
      pmc: @pmc,
      votelink: @votelink,
      noticelink: @noticelink
    }

    @disabled = true
    @alert = nil
    console.log('>previewInvitation: ' + data.inspect)
    post 'validate', data do |response|
      console.log('<previewInvitation: ' + response.inspect)
      @disabled = false
      @alert = response.error
      @memberEmail = response.memberEmail
      @userEmail = response.userEmail
      @pmcEmail = response.pmcEmail
      @invitation = response.invitation
      @token = response.token
      document.getElementById(response.focus).focus() if response.focus
      jQuery('#invitation-preview').modal(:show) unless @alert
    end
  end
  def previewDiscussion()
    data = {
      iclaname: @iclaname,
      iclaemail: @iclaemail,
      pmc: @pmc,
      proposer: @member,
      subject: @subject,
      proposalText: @proposalText,
      discussComment: @discussComment
    }

    @disabled = true
    @alert = nil
    console.log('>previewDiscussion: ' + data.inspect)
    post 'discuss', data do |response|
      console.log('<previewDiscussion: ' + response.inspect)
      @disabled = false
      @alert = response.error
      @memberEmail = response.memberEmail
      @userEmail = response.userEmail
      @pmcEmail = response.pmcEmail
      @discussion = response.discussion
      @token = response.token
      @message = response.message
      document.getElementById(response.focus).focus() if response.focus
      jQuery('#discussion-preview').modal(:show) unless @alert
    end
  end
  def previewVote()
    data = {
      user: @user,
      iclaname: @iclaname,
      iclaemail: @iclaemail,
      pmc: @pmc,
      proposer: @member,
      subject: @subject,
      proposalText: @voteProposalText,
      voteComment: @voteComment,
      voteComment: @voteComment
    }

    @disabled = true
    @alert = nil
    console.log('>previewVote: ' + data.inspect)
    post 'vote', data do |response|
      console.log('<previewVote: ' + response.inspect)
      @disabled = false
      @alert = response.error
      @memberEmail = response.memberEmail
      @userEmail = response.userEmail
      @pmcEmail = response.pmcEmail
      @token = response.token
      @message = response.message
      document.getElementById(response.focus).focus() if response.focus
      jQuery('#vote-preview').modal(:show) unless @alert
    end
  end

  # pretend to send an invitation
  def mockSend()
    # dismiss modal dialog
    jQuery('#invitation-preview').modal(:hide)

    # save information for later use (for demo purposes, this is client only)
    FormData.token = @token
    FormData.fullname = @iclaname
    FormData.email = @iclaemail
    FormData.pmc = @pmc
    FormData.votelink = @votelink
    FormData.noticelink = @noticelink

    # for demo purposes advance to the interview.  Note: the below line
    # updates the URL in a way that breaks the back button.
    history.replaceState({}, nil, "form?token=#@token")

    # change the view
    Main.navigate(Interview)
  end
end
