#
# Send initial and final reminders.  Note that this is a form (with an
# associated button) as well as a second button.
#

class InitialReminder < React
  def initialize
    @disabled = true
    @subject = ''
    @message = ''
  end

  # default attributes for the button associated with this form
  def self.button
    {
      text: 'send initial reminders',
      class: 'btn_primary',
      data_toggle: 'modal',
      data_target: '#reminder-form'
    }
  end

  # fetch email template
  def loadText(event)
    if event.target.textContent == 'send initial reminders'
      reminder = 'reminder1'
    else
      reminder = 'reminder2'
    end

    fetch reminder, :json do |response|
      @subject = response.subject
      @message = response.body
      @disabled = false
    end
  end

  # wire up event handlers
  def componentDidMount()
    Array(document.querySelectorAll('.btn-primary')).each do |button|
      if button.getAttribute('data-target') == '#reminder-form'
        button.onclick = self.loadText
      end
    end
  end

  # commit form: allow the user to confirm or edit the commit message
  def render
    _ModalDialog.reminder_form!.wide_form color: 'blank' do
      # header
      _h4 'Email message'

      # input field for the subject
      _input.email_subject! value: @subject, disabled: @disabled, 
        label: 'subject', placeholder: 'loading...'

      # text area input field for the body
      _textarea.email_text! value: @message, rows: 12, 
        disabled: @disabled, label: 'body', placeholder: 'loading...'

      # buttons
      _button.btn_default 'Close', data_dismiss: 'modal'
      _button.btn_info 'Dry Run', onClick: self.click, disabled: @disabled
      _button.btn_primary 'Submit', onClick: self.click, disabled: @disabled
    end
  end

  # on click, disable the input fields and buttons and submit
  def click(event)
    @disabled = true
    dryrun = (event.target.textContent == 'Dry Run')

    # data to be sent to the server
    data = {
      dryrun: dryrun,
      agenda: Agenda.file,
      subject: @subject,
      message: @message,
      pmcs: []
    }

    # collect up a list of PMCs that are checked
    Array(document.querySelectorAll('input[type=checkbox]')).each do |input|
      data.pmcs << input.value if input.checked
    end

    post 'send-reminders', data do |response|
      if not response
        alert("Server error - check console log")
      elsif dryrun
        console.log response
        alert("Dry run - check console log")
      elsif response.count == data.pmcs.length
        alert("Reminders have been sent to: #{data.pmcs.join(', ')}.")
      elsif response.count and response.unsent
        alert("Error: no emails were sent to #{response.unsent.join(', ')}")
      else
        alert("No reminders were sent")
      end

      @disabled = false
      jQuery('#reminder-form').modal(:hide)
      document.body.classList.remove('modal-open')
    end
  end
end

#
# A button for final reminders
#
class FinalReminder < React
  def render
    _button.btn.btn_primary 'send final reminders', 
      data_toggle: 'modal', data_target: '#reminder-form'
  end
end
