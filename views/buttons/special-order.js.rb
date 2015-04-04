#
# Add a new special order to the agenda.
#

class SpecialOrder < React
  def initialize
    @disabled = false
  end

  # default attributes for the button associated with this form
  def self.button
    {
      text: 'post special order',
      class: 'btn_primary',
      data_toggle: 'modal',
      data_target: '#special-order-form'
    }
  end

  def render
    _ModalDialog.special_order_form! color: 'commented' do
      _h4 'Add Special Order'

      #input field: title
      _input.special_order_title! label: 'title', disabled: @disabled,
        placeholder: 'title'

      #input field: report text
      _textarea.special_order_text! label: 'resolution',
        placeholder: 'resolution', rows: 17, disabled: @disabled

      # footer buttons
      _button.btn_default 'Cancel', data_dismiss: 'modal', disabled: @disabled
      _button.btn_primary 'Submit', onClick: self.submit, disabled: @disabled
    end
  end

  # autofocus on title
  def componentDidMount()
    jQuery('#special-order-form').on 'shown.bs.modal' do
      ~'#special-order-title'.focus()
    end
  end

  # when save button is pushed, post comment and dismiss modal when complete
  def submit(event)
    data = {
      agenda: Agenda.file,
      attach: '7?',
      title: ~'#special_order_title'.value,
      report: ~'#special_order_text'.value
    }

    @disabled = true
    post 'post', data do |response|
      jQuery('#special-order-form').modal(:hide)
      @disabled = false
      Agenda.load response.agenda
      Main.refresh()
    end
  end
end
