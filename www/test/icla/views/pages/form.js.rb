class Form < React
  def initialize
    @disabled = false
    @alert = nil

    @fullName = ''
    @publicName = ''
    @address = ''
    @country = ''
    @telephone = ''
    @apacheId = ''
  end

  def render
    # error messages / welcome
    if @alert
      _div.alert.alert_danger do
        _b 'Error: '
        _span @alert
      end
    else
      _p %{
        Thanks!  Now please take a moment to answer a few questions about
        yourself.
      }
    end

    #
    # Form fields
    #

    _div.form_group do
      _p 'Full Name:'
      _input.form_control value: @fullName, onChange: self.setName,
        required: true
    end

    _div.form_group do
      _p '(Optional) Public Name:'
      _input.form_control value: @publicName
    end

    _div.form_group do
      _p 'Mailing Address:'
      _textarea.form_control.address! value: @address, rows: 2
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
        _input.form_control value: @apacheId, pattern: "^[a-z][-a-z0-9_]+$"
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

  # initialize full name from invitation
  def componentWillMount()
    @fullName = FormData.fullname
  end

  # when the form is initially loaded, set the focus on the address field
  def componentDidMount()
    document.getElementById('address').focus()
  end

  # as a convenience, preset public name if the user changes the full name
  def setName(event)
    @publicName = @fullName unless @publicName
    @fullName = event.target.value
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
        Main.navigate(Preview)
      end
    end
  end
end
