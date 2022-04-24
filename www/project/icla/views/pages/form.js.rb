class Form < Vue
  def initialize
    @disabled = true
    @alert = nil

    @fullName = ''
    @publicName = ''
    @address = ''
    @country = ''
    @telephone = ''
    @apacheId = ''
  end

  def render

    _p %{
      Thanks!  Now please take a moment to answer a few questions about
      yourself.
    }

    #
    # Form fields
    #

    _div.form_group do
      _p 'Full Name:'
      _input.form_control.fullname! value: @fullName, required: true,
        placeholder: 'GivenName FamilyName',
        onChange: self.setFullName
    end

    _div.form_group do
      _p 'Public Name (if different from Full Name):'
      _input.form_control value: @publicName
    end

    _div.form_group do
      _p 'Postal Address:'
      _textarea.form_control value: @address, rows: 2
    end

    _div.form_group do
      _p 'Country:'
      _input.form_control value: @country
    end

    _div.form_group do
      _p 'Telephone:'
      _input.form_control value: @telephone
    end

    if FormData.votelink
      _div.form_group do
        _p 'Preferred Apache Id:'
        _input.form_control.apacheId! value: @apacheId,
          placeholder: 'At least 3 lower-case alphanumeric, starting with alpha. Separate multiple choices with spaces.',
          pattern: "^[a-z][a-z0-9]{2,}{1,}\s*(\s+[a-z][a-z0-9]{2,}{1,})*$"
          # Single name, optional spaces after, followed by zero or more names with leading spaces
      end
    end

    # needs to be near the button or it can scroll off the visible screen
    if @alert
      _div.alert.alert_danger do
        _b 'Error: '
        _span @alert
      end
    end

    #
    # Submit button
    #

    _p do
      _button.btn.btn_primary 'Submit', disabled: @disabled,
        onClick: self.submit
    end
  end

  # initialize public name from invitation
  def created()
    @publicName = FormData.fullname
  end

  # when the form is initially loaded, set the focus on the address field
  def mounted()
    document.getElementById('fullname').focus()
  end

  # enable submit button when name is present
  def setFullName(event)
    @fullName = event.target.value
    @disabled = (event.target.value == '')
  end

  # submit the form
  def submit()
    FormData.fullname = @fullName
    FormData.publicname = @publicName
    FormData.address = @address
    FormData.country = @country
    FormData.telephone = @telephone
    FormData.apacheid = @apacheId

    @disabled = true
    @alert = nil
    post 'draft-icla', FormData do |response|
      @disabled = false

      if response.error
        @alert = response.error
        document.getElementById(response.focus).focus() if response.focus
      else
        FormData.draft = response.draft
        FormData.ipaddr = response.ipaddr
        Main.navigate(Preview)
      end
    end
  end
end
