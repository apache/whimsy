class Discuss < Vue
  def initialize
    @disabled = true
    @alert = nil
    console.log('date now: ' + Date.new().toLocaleString())

    # initialize form fields
    @member = Server.data.member
    @token = Server.data.token
    @debug = Server.data.debug
    console.log('discuss')
    console.log('token: ' + @token)
    console.log('member: ' + @member)
    @progress = Server.data.progress
    console.log('progress: ' + @progress.inspect)
    if @progress
      @phase = @progress[:phase]
    else
      @phase = 'unknown' # flag
    end
    console.log('phase: ' + @phase)
    if not @token
      @alert = "Token is required for this page"
    elsif @phase == 'unknown'
      @alert = "Cannot determine phase: could not read token file"
    elsif @phase == 'error'
      @alert = @progress[:errorMessage]
    elsif @phase != 'discuss'
      @alert = "Wrong phase: " + @phase + "; should be discuss"
    else
      @pmc = @progress[:project]
      @proposer = @progress[:proposer]
      @contributor = @progress[:contributor]
      @iclaname = @contributor[:name]
      @iclaemail = @contributor[:email]
      @comments = @progress[:comments]
      @discussBody = ''
      @subject = @progress[:subject]
    end

  end

  def render
    _p %{
      This form allows PMC and PPMC members to
      discuss contributors to achieve consensus.
    }
    if @phase == 'discuss'
      _b "Project: " + @pmc
      _p
      _b "Contributor: " + @iclaname + " (" + @iclaemail + ")"
      _p
      _b "Proposed by: " + @proposer
      _p
      _p "Subject: " + @subject
      _p
      #
      # Form fields
      #
      _div.form_group do
        _label "Comment from " + @member + ' (required)', :for => 'discussBody'
        _textarea.form_control rows: 4,
        required: true, placeholder: 'new comment',
        id: 'discussBody', value: @discussBody,
        onChange: self.setDiscussBody
      end
      @comments.each {|c|
        _b 'From: ' + c.member + ' Date: ' + c.timestamp
        _p c.comment
      }
      #
      # Submission buttons
      #

      _p do
        _button.btn.btn_primary 'Submit comment and continue to discuss',
        disabled: @disabled,
        onClick: self.submitComment
        _b ' or '
        _button.btn.btn_primary 'Submit comment and start voting',
        disabled: @disabled,
        onClick: self.startVoting
        _b ' or '
        _button.btn.btn_primary 'Submit comment and invite contributor to submit ICLA',
        disabled: @disabled,
        onClick: self.invite
      end
    end
    if @debug
      _p 'token: ' + @token.to_s
      _p 'comment: ' + @discussBody.inspect
      _p 'progress: ' + @progress.inspect
    end

    # error messages
    if @alert
      _div.alert.alert_danger do
        _b 'Error: '
        _span @alert
      end
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
              _span @memberEmail
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

  end

  # when the form is initially loaded, set the focus on the discussBody field
  def mounted()
    document.getElementById('discussBody').focus() if not @alert
  end

  #
  # field setters
  #

  def setDiscussBody(event)
    @discussBody = event.target.value
    checkValidity()
  end

  def setInvitation(event)
    @invitation = event.target.value
    checkValidity()
  end

  def submitComment(event)
    console.log('submitComment discussBody: ' + @discussBody.inspect)
    updateVoteFile('submitComment')
  end

  def startVoting(event)
    console.log('startVoting discussBody: ' + @discussBody.inspect)
    updateVoteFile('startVoting','vote')
  end

  def invite(event) # does this need to change to 'invite'
    console.log('invite discussBody: ' + @discussBody.inspect)
    updateVoteFile('invite')
  end

  def updateVoteFile(action, newPhase)
    data = {
      action: action,
      token: @token,
      member: @member,
      comment: @discussBody,
      expectedPhase: 'discuss',
      newPhase: newPhase,
    }
    console.log(">update: "+ data.inspect) # debug
    post 'update', data do |response|
      console.log("<update: "+ response.inspect) # debug
      @alert = response.error
      @comments = response['contents']['comments'] unless @alert
    end
  end

  #
  # validation and processing
  #

  # client side field validations
  def checkValidity()
    @disabled = !%w(discussBody).all? do |id|
      element = document.getElementById(id)
      not element.empty?
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
