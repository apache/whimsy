class Vote < Vue
  def initialize
    @disabled = true
    @alert = nil

    # initialize form fields
    @token = Server.data.token
    @member = Server.data.member
    @debug = Server.data.debug
    console.log('vote')
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
    elsif @phase != 'vote'
      @alert = "Wrong phase: " + @phase + "; should be vote"
    else
      @pmc = @progress[:project]
      console.log('pmc: ' + @pmc)
      @proposer = @progress[:proposer]
      @contributor = @progress[:contributor]
      @iclaname = @contributor[:name]
      @iclaemail = @contributor[:email]
      @comments = @progress[:comments]
      @votes = @progress[:votes]
      @vote = ''
      @timestamp = ''
      @commentBody = ''
      @subject = @progress[:subject]
      @showComment = false;
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
          onClick: lambda {@vote = '+1'; @showComment = false; checkValidity()}
          _span " +1 approve "
        end
        _p
        _label do
          _input type: 'radio', name: 'vote', value: '+0',
          onClick: lambda {@vote = '+0'; @showComment = false; checkValidity()}
          _span " +0 don't care "
        end
        _p
        _label do
          _input type: 'radio', name: 'vote', value: '-0',
          onClick: lambda {@vote = '-0'; @showComment = false; checkValidity()}
          _span " -0 don't care "
        end
        _p
        _label do
          _input type: 'radio', name: 'vote', value: '-1',
          onClick: lambda {@vote = '-1'; @showComment = true; checkValidity()}
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

      _h5 'Voting history'

      tally = {} # most recent vote details for each member
      # previous votes
      @votes.each {|v|
        tally[v.member] = [v.vote, v.timestamp]
        _p v.vote + ' From: ' + v.member + ' Date: ' + v.timestamp
      }

      _h5 'Summary of voting so far'

      vote_count = {}
      tally.each_key { |k|
        vote_count[tally[k][0]] ||= 0
        vote_count[tally[k][0]] += 1
        _ k + ' ' + tally[k][0] + ' ' + tally[k][1]
        _br
      }

      _br

      vote_count.each_key {|k|
        _ k + ': ' + vote_count[k]
        _br
      }

      started = new Date(@votes[0]['timestamp'])
      now = new Date()
      elapsed = (now - started) / (1000 * 60 * 60)
      _ 'Voting started: ' + started.toISOString() + ' Hours elapsed: ' + elapsed.to_i

      _p

      _h5 'Previous discussion'

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
              _label :for => 'invitation'
              _textarea.form_control.invitation! value: @invitation, rows: 12,
                onChange: self.setInvitation # does not appear to work
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

  # TODO: finish the code!
  def setInvitation(event)
    console.log('setInvitation:' + event)
    alert('setInvitation: Not yet implemented')
  end

  def submitVote(event)
    console.log('submitVote:' + event)
    updateVoteFile('submitVote')
  end

  def cancelVote(event)
    console.log('cancelVote:' + event)
    updateVoteFile('cancelVote', 'cancelled')
  end

  def tallyVote(event)
    console.log('tallyVote:' + event)
    updateVoteFile('tallyVote', 'tallied') # is this correct? TODO
  end

  def updateVoteFile(action, newPhase)
    data = {
      action: action,
      vote: @vote,
      member: @member,
      token: @token,
      expectedPhase: 'vote',
      newPhase: newPhase,
    }
    data['comment']=@commentBody if @vote == '-1'
    console.log(">update: "+ data.inspect) # debug
    post 'update', data do |response|
      console.log("<update: "+ response.inspect) # debug
      @alert = response.error
      unless @alert
        @votes = response['contents']['votes']
        @comments = response['contents']['comments']
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
