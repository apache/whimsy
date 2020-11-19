#
# Send initial and final reminders.  Note that this is a form (with an
# associated button) as well as a second button.
#

class InitialReminder < Vue
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
      disabled: true,
      data_toggle: 'modal',
      data_target: '#reminder-form'
    }
  end

  # fetch email template
  def loadText(event)
    if event.target.textContent.include? 'non-responsive'
      reminder = 'non-responsive'
    elsif event.target.textContent.include? 'initial'
      reminder = 'reminder1'
    else
      reminder = 'reminder2'
    end

    retrieve reminder, :json do |response|
      @subject = response.subject
      @message = response.body
      @disabled = false

      if reminder == 'non-responsive'
        @selection = 'inactive'
      else
        @selection = 'active'
      end
    end
  end

  # wire up event handlers
  def mounted()
    Vue.nextTick do
      Array(document.querySelectorAll('button')).each do |button|
        if button.getAttribute('data-target') == '#reminder-form'
          button.disabled = false
          button.addEventListener :click, self.loadText
        end
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
    event.target.disabled = true
    @disabled = true
    dryrun = (event.target.textContent == 'Dry Run')

    # data to be sent to the server
    data = {
      dryrun: dryrun,
      agenda: Agenda.file,
      subject: @subject,
      message: @message,
      selection: @selection,
      pmcs: []
    }

    # collect up a list of PMCs that are checked
    Array(document.querySelectorAll('input[type=checkbox]')).each do |input|
      if input.checked and input.classList.contains(@selection)
        data.pmcs << input.value
      end
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
        alert("Error: no emails were sent to #{response.unsent.inspect}")
      else
        alert("No reminders were sent")
      end

      event.target.disabled = true
      @disabled = false
      jQuery('#reminder-form').modal(:hide)
      document.body.classList.remove('modal-open')
    end
  end
end

#
# A button for final reminders
#
class FinalReminder < Vue
  def render
    _button.btn.btn_primary 'send final reminders', disabled: true,
      data_toggle: 'modal', data_target: '#reminder-form'
  end
end

#
# A button for warning non-responsive PMCs
#
class ProdReminder < Vue
  def render
    _button.btn.btn_danger 'prod non-responsive PMCs', disabled: true,
      data_toggle: 'modal', data_target: '#reminder-form'
  end
end
