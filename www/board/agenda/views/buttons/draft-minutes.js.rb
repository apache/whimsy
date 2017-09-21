class DraftMinutes < Vue
  def initialize
    @disabled = true
  end

  # default attributes for the button associated with this form
  def self.button
    {
      text: 'draft minutes',
      class: 'btn_danger',
      data_toggle: 'modal',
      data_target: '#draft-minute-form'
    }
  end

  def render
    _ModalDialog.draft_minute_form!.wide_form color: 'commented' do
      _h4.commented 'Commit Draft Minutes to SVN'

      _textarea.draft_minute_text!.form_control rows: 17, tabIndex: 1,
        placeholder: 'minutes', value: @draft, disabled: @disabled

      # variable number of buttons
      _button.btn_default 'Cancel', type: 'button', data_dismiss: 'modal'

      _button.btn_primary 'Save', type: 'button', onClick: self.save,
        disabled: @disabled
    end
  end

  # autofocus on minute text; fetch draft
  def mounted()
    @draft = ''
    jQuery('#draft-minute-form').on 'shown.bs.modal' do
      retrieve "draft/#{Agenda.title.gsub('-', '_')}", :text do |draft|
        document.getElementById("draft-minute-text").focus()
        @disabled = false
        @draft = draft
        jQuery('#draft-minute-text').animate(scrollTop: 0)
      end
    end
  end

  def save(event)
    data = {
      agenda: Agenda.file,
      message: "Draft minutes for #{Agenda.title}",
      text: @draft
    }

    @disabled = true
    post 'draft', data do
      @disabled = false
      jQuery('#draft-minute-form').modal(:hide)
      document.body.classList.remove('modal-open')
    end
  end
end
