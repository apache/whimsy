class Interview < Vue
  def initialize
    @showQuestion1 = false
    @showQuestion2 = false
    @showQuestion3 = false

    @disableButton1 = false
    @disableButton2 = false
    @disableButton3 = false

    @disablePersonalDetails = false
    @alert = nil
  end

  def render
    _p.alert.alert_info %{
      For demo purposes, assume that you are now the invitee, you received the
      email, and clicked on the link.  Below is what you would see.
    }

    _p %{
      Welcome to the Apache Software Foundation Individual Contributor License
      Agreement (ICLA) online submission tool! This tool will guide you through the
      process of licensing to the ASF any copyright and patents that may apply
      to your contributions.
    }

    _p %{
      This process should only take a few minutes, and is entirely online.
      First we will ask you verify your email address and Public Name.
      Next, we will ask you three questions. Then, you will be asked to
      provide some information about yourself. Finally, you will get a chance
      to review and submit the completed form.
    }

    _div.form_group do
      _p 'Full Name:'
      _input.form_control.fullname! value: @fullName, required: true,
        placeholder: 'Enter the name you used previously',
        onChange: self.setFullName, disabled: @disablePersonalDetails
    end

    _div.form_group do
      _p 'Email Address:'
      _input.form_control.emailAddress! value: @emailAddress, required: true,
        placeholder: 'Enter the address you used previously',
        onChange: self.setEmailAddress, disabled: @disablePersonalDetails
    end

    # error messages
    if @alert
      _div.alert.alert_danger do
        _b 'Error: '
        _span @alert
      end
    end

    #
    # Question 1
    #

    if @showQuestion1
      _h2 'Question 1'

      _p %{
        Are you are legally entitled to grant the necessary copyright and
        patent licenses?  If any employer has intellectual property rights to
        any of your Contributions:
      }

      _ul do
        _li "have you received permission to make Contributions on behalf
             of that employer, or"
        _li "has your employer waived such rights for your Contributions to
             the Foundation, or"
        _li "has your employer executed a separate Corporate CLA with the
             Foundation?"
      end

      _p do
        _button.btn.btn_primary 'Yes', disabled: @disableButton1,
          onClick: self.clickButton1
      end
    end

    #
    # Question 2
    #

    if @showQuestion2
      _h2 'Question 2'
      _p %{
        Are each of your contributions is your original creation? Do each of
        your contribution submissions include complete details of any
        third-party license or other restriction (including, but not limited
        to, related patents and trademarks) of which you are personally aware
        and which are associated with any part of Your Contributions?
      }

      _p.alert.alert_success do
        _b 'Note: '
        _span %{
          Should you wish to submit work that is not your original creation,
          you may submit it to the Foundation separately from any other
          contribution, identifying the complete details of its source and of
          any license or other restriction (including, but not limited to,
          related patents, trademarks, and license agreements) of which you
          are personally aware, and conspicuously marking the work as
          "Submitted on behalf of a third-party: [named here]".
        }
      end

      _p do
        _button.btn.btn_primary 'Yes', disabled: @disableButton2,
          onClick: self.clickButton2
      end
    end

    #
    # Question 3
    #

    if @showQuestion3
      _h2 'Question 3'
      _p %{
        Do you agree to notify the Foundation of any facts or circumstances of
        which you become aware that would make these representations
        inaccurate in any respect?
      }

      _p do
        _button.btn.btn_primary 'Yes', disabled: @disableButton3,
          onClick: self.clickButton3
      end

      _p %{
        Once you agree to this, the tool will ask you some questions
        about yourself.
      }
    end
  end

  def validatePerson
    if @fullName and @fullName != '' and @emailAddress and @emailAddress != ''
      if @fullName == FormData.fullname and @emailAddress == FormData.email # TODO proper validation
        @showQuestion1 = true
        @disablePersonalDetails = true # no further changes allowed
        @alert = nil
      else
        @alert = 'Cannot validate details'
      end
    end
  end

  def setFullName(event)
    @fullName = event.target.value
    validatePerson
  end

  # enable submit button when name is present
  def setEmailAddress(event)
    @emailAddress = event.target.value
    validatePerson
  end

  def clickButton1()
    @disableButton1 = true
    @showQuestion2 = true
  end

  def clickButton2()
    @disableButton2 = true
    @showQuestion3 = true
  end

  def clickButton3()
    Main.navigate(Form)
  end
end
