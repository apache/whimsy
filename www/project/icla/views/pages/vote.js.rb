class Vote < Vue
  def initialize
    @disabled = true
    @alert = nil

    # initialize form fields
    @member = Server.data.member
    console.log('vote')
    console.log('token: ' + Server.data.token)
    console.log('member: ' + @member)
    @progress = Server.data.progress
    console.log('progress: ' + @progress.inspect)
    @phase = @progress[:phase]
    console.log('phase: ' + @phase)
    if @phase == 'error'
      @alert = @progress[:errorMessage]
    elsif @phase != 'vote'
      @alert = "Wrong phase: " + @phase + "; should be vote"
    else
    @pmc = @progress[:project]
    @proposer = @progress[:proposer]
    @contributor = @progress[:contributor]
    @iclaname = @contributor[:name]
    @iclaemail = @contributor[:email]
    @token = Server.data.token
    @comments = @progress[:comments]
    @votes = @progress[:votes]
    @vote = ''
    @timestamp = ''
    @commentBody = ''
    @subject = @progress[:subject]
    @showComment = false;
    @debug = Server.data.debug
    end
  end

  def render
    _p %{
      This form allows PMC and PPMC members to
      vote to invite a contributor to become a committer or a PMC/PPMC member.
    }
    if @phase == 'vote'
      _b "Project: " + @pmc
      _p
      _b "Contributor: " + @iclaname + " (" + @iclaemail + ")"
      _p
      _b "Proposed by: " + @proposer
      _p
      _p "Subject: " + @subject
      _p
      _div.form_group.vote do
        _label do
          _input type: 'radio', name: 'vote', value: '+1',
          onClick: -> {@vote = '+1'; @showComment = false; checkValidity()}
          _span " +1 approve "
        end
        _p
        _label do
          _input type: 'radio', name: 'vote', value: '+0',
          onClick: -> {@vote = '+0'; @showComment = false; checkValidity()}
          _span " +0 don't care "
        end
        _p
        _label do
          _input type: 'radio', name: 'vote', value: '-0',
          onClick: -> {@vote = '-0'; @showComment = false; checkValidity()}
          _span " -0 don't care "
        end
        _p
        _label do
          _input type: 'radio', name: 'vote', value: '-1',
          onClick: -> {@vote = '-1'; @showComment = true; checkValidity()}
          _span " -1 disapprove, because... "
        end
        _p
      end

      #
      # Form fields
      #
      if @showComment
        _div.form_group do
          _textarea.form_control rows: 4,
          placeholder: 'reason to disapprove',
          id: 'commentBody', value: @commentBody,
          onChange: self.setCommentBody
        end
      end

      # previous votes
      @votes.each {|v|
        _p v.vote + ' From: ' + v.member + ' Date: ' + v.timestamp
      }

      # previous comments
      @comments.each {|c|
        _b 'From: ' + c.member + ' Date: ' + c.timestamp
        _p c.comment
      }

      #
      # Submission buttons
      #
      _p do
        _button.btn.btn_primary 'Submit my vote', disabled: @disabled,
        onClick: self.submitVote
        _b ' or '
        _button.btn.btn_primary 'Cancel the vote', disabled: false,
        onClick: self.cancelVote
        _b ' or '
        _button.btn.btn_primary 'Tally the vote', disabled: false,
        onClick: self.tallyVote
      end
    end

    if @debug
      _p 'token: ' + @token
      _p 'comment: ' + @commentBody
      _p 'vote: ' + @vote
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

  # when the form is redisplayed, e.g. after displaying/hiding the commentBody
  def updated()
    focusComment()
  end

  # when the form is initially loaded
  def mounted()
  end

  #
  # field setters
  #
  def setCommentBody(event)
    @commentBody = event.target.value
    checkValidity()
  end

  def focusComment()
    f = document.getElementById('commentBody')
    f.focus() if f
  end

  #
  # validation and processing
  #

  # client side field validations
  def checkValidity()
    # disabled if no vote or vote -1 without comment
    @disabled = (@vote == '' or (@vote == '-1' and @commentBody.empty?))
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
      @memberEmail = response.memberEmail
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
