class Discuss < Vue
  def initialize
    @disabled = true
    @alert = nil

    # initialize form fields
    @user = Server.data.user
    @pmc = Server.data.contributor[:project]
    @iclaname = Server.data.contributor[:name]
    @iclaemail = Server.data.contributor[:email]
    @token = Server.data.token
    @comments = Server.data.comments
    @discussBody = ''
    @subject = Server.data.subject
    @debug = false;

  end

  def render
    _p %{
      This form allows PMC and PPMC members to
      discuss contributors to achieve consensus.
    }
    _b "Project: " + @pmc
    _p
    _b "Contributor: " + @iclaname + " (" + @iclaemail + ")"
    _p
    _p "Subject: " + @subject
    _p
    #
    # Form fields
    #
    _div.form_group do
      _label "Comment from " + @user, for: 'discussBody'
      _textarea.form_control rows: 4,
      required: true, placeholder: 'new comment',
      id: 'discussBody', value: @discussBody,
      onChange: self.setDiscussBody
    end
    @comments.each {|c|
      _b 'From: ' + c.member + ' Date: ' + c.timestamp
      _p c.comment
    }
if @debug
    _p 'token: ' + @token
    _p 'comment: ' + @discussBody
end
    # error messages
    if @alert
      _div.alert.alert_danger do
        _b 'Error: '
        _span @alert
      end
    end


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
              _label for: 'invitation'
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
    document.getElementById('discussBody').focus()
  end

  #
  # field setters
  #

  def setDiscussBody(event)
    @discussBody = event.target.value
    checkValidity()
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

  # server side field validations
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
    post 'validate', data do |response|
      @disabled = false
      @alert = response.error
      @userEmail = response.userEmail
      @pmcEmail = response.pmcEmail
      @invitation = response.invitation
      @token = response.token
      document.getElementById(response.focus).focus() if response.focus
      jQuery('#invitation-preview').modal(:show) unless @alert
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
