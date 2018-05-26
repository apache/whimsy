class Summary < Vue
  def initialize
    @disabled = true
  end

  # default attributes for the button associated with this form
  def self.button
    {
      text: 'send summary',
      class: 'btn_danger',
      data_toggle: 'modal',
      data_target: '#summary-form'
    }
  end

  def render
    _ModalDialog.summary_form!.wide_form color: 'commented' do
      _h4.commented 'Send out meeting summary to committers'

      _textarea.summary_text!.form_control rows: 17, tabIndex: 1,
        placeholder: 'committers summary', value: @summary, disabled: @disabled

      _button.btn_default 'Cancel', type: 'button', data_dismiss: 'modal'
      _button.btn_primary 'Send', type: 'button', onClick: self.send,
        disabled: @disabled
    end
  end

  # autofocus on summary text; fetch summary
  def mounted()
    @summary = ''
    jQuery('#summary-form').on 'show.bs.modal' do
      retrieve "summary/#{Agenda.title}", :text do |summary|
        document.getElementById("summary-text").focus()
        @disabled = false
        @summary = summary
        jQuery('#summary-text').animate(scrollTop: 0)
      end
    end
  end

  def send(event)
    @disabled = true
    post 'summary', agenda: Agenda.file, text: @summary do |response|
      Minutes.load response.minutes
      @disabled = false
      jQuery('#summary-form').modal(:hide)
      document.body.classList.remove('modal-open')
    end
  end
end
