#
# Send reminders for action items
#
class ActionReminder < Vue
  def initialize
    @disabled = false
    @list = @@item.actions.map do |action|
      Object.assign({complete: action.status != ""}, action)
    end
  end

  # default attributes for the button associated with this form
  def self.button
    {
      text: 'send reminders',
      class: 'btn_primary',
      data_toggle: 'modal',
      data_target: '#reminder-form'
    }
  end

  # commit form: allow the user to select which reminders to send
  def render
    _ModalDialog.reminder_form!.wide_form color: 'blank' do
      # header
      _h4 'Send reminders'

      _pre.report do
        @list.each do |action|
          _CandidateAction action: action
        end
      end

      # buttons
      _button.btn_default 'Close', data_dismiss: 'modal'
      _button.btn_info 'Dry Run', onClick: self.click, disabled: @disabled
      _button.btn_primary 'Submit', onClick: self.click, disabled: @disabled
    end
  end

  def click(event)
    dryrun = (event.target.textContent == 'Dry Run')

    data = {
      dryrun: dryrun,
      agenda: Agenda.file,
      actions: @list.select {|item| !item.complete}
    }

    @disabled = true
    post 'remind-actions', data do |response|
      if not response
        alert("Server error - check console log")
      elsif dryrun
        console.log Object.values(response.sent).join("\n---\n\n")
        response.delete(:sent)
        console.log response
        alert("Dry run - check console log")
      elsif response.count == @list.length
        alert("Reminders have been sent to: #{response.sent.keys.join(', ')}.")
      elsif response.count and response.unsent
        alert("Error: no emails were sent to #{response.unsent.inspect}")
      else
        alert("No reminders were sent")
      end

      @disabled = false
      Agenda.load response.agenda, response.digest
      jQuery('#reminder-form').modal(:hide)
      document.body.classList.remove('modal-open')
    end
  end
end
