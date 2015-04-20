class Invite < React
  def initialize
    @disabled = true
    @alert = nil

    # initialize form fields
    @iclaname = ''
    @iclaemail = ''
    @pmc = ''
    @votelink = ''
  end

  def render
    _p %{
      You've come to this page because a contributor has has submitted
      a large patch or because your PMC has voted in a new committer.
      Invite them to fill out an Individual Contributor License Agreement
      by filling out the following form.
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
      _label "Contributor's Name:", for: 'iclaname'
      _input.form_control.iclaname! placeholder: 'Firstname Lastname',
        required: true, onChange: self.setIclaName, value: @iclaname
    end

    _div.form_group do
      _label "Contributor's E-Mail address:", for: 'iclaemail'
      _input.form_control.iclaemail! type: 'email', required: true,
        placeholder: 'user@example.com', onChange: self.setIclaEmail,
        value: @iclaemail
    end

    _div.form_group do
      _label "PMC", for: 'pmc'
      _select.form_control.pmc! required: true, onChange: self.setPMC, value: @pmc do
        _option ''
        Server.data.pmcs.each do |pmc|
          _option pmc
        end
      end
    end

    _p %{
      Fill out the following only if the person was voted by the PMC to
      become a committer.
    }

    _div.form_group do
      _label "Vote link", for: 'votelink'
      _input.form_control.votelink! type: 'url', onChange: self.setVoteLink,
        value: @votelink
    end

    #
    # Submission button
    #

    _p do
      _button.btn.btn_primary 'Preview Invitation', disabled: @disabled,
        onClick: self.previewInvitation
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

  # when the form is initially loaded, set the focus on the iclaname field
  def componentDidMount()
    document.getElementById('iclaname').focus()
  end

  #
  # field setters
  #

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
    self.checkValidity()
  end

  def setVoteLink(event)
    @votelink = event.target.value
    self.checkValidity()
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
    @disabled = !%w(iclaname iclaemail pmc votelink).all? do |id|
      document.getElementById(id).checkValidity()
    end
  end

  # server side field validations
  def previewInvitation()
    data = {
      iclaname: @iclaname,
      iclaemail: @iclaemail,
      pmc: @pmc,
      votelink: @votelink
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

    # for demo purposes advance to the interview.  Note: the below line
    # updates the URL in a way that breaks the back button.
    history.replaceState({}, nil, "form?token=#@token")

    # change the view
    Main.navigate(Interview)
  end
end
