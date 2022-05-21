class PublishMinutes < Vue
  def initialize
    @disabled = false
    @previous_title = nil
  end

  # default attributes for the button associated with this form
  def self.button
    {
      text: 'publish minutes',
      class: 'btn_danger',
      data_toggle: 'modal',
      data_target: '#publish-minutes-form'
    }
  end

  def render
    _ModalDialog.publish_minutes_form!.wide_form color: 'commented' do
      _h4.commented 'Publish Minutes onto the ASF web site'

      _textarea.summary_text!.form_control rows: 10, tabIndex: 1,
        value: @summary, disabled: @disabled, label: 'Minutes summary'

      _input.message! label: 'Commit message', value: @message,
        disabled: @disabled

      _button.btn_default 'Cancel', type: 'button', data_dismiss: 'modal'
      _button.btn_primary 'Submit', type: 'button', onClick: self.publish,
        disabled: @disabled
    end
  end

  # On first load, ensure summary is produced
  def created()
    if @@item.title != @previous_title
      if not @@item.attach
        # Index page for a path month's agenda
        self.summarize Agenda.index, Agenda.title.gsub('-', '_')
      elsif defined? XMLHttpRequest
        # Minutes from previous meetings section of the agenda
        date = @@item.text[/board_minutes_(\d+_\d+_\d+)\.txt/, 1]
        url = document.baseURI.sub(/[-\d]+\/$/, date.gsub('_', '-')) + '.json'

        retrieve url, :json do |agenda|
          self.summarize agenda, date
        end
      end

      @previous_title = @@item.title
    end
  end

  # autofocus on minute text
  def mounted()
    jQuery('#publish-minutes-form').on 'shown.bs.modal' do
      document.getElementById("summary-text").focus()
    end
  end

  # compute default summary for web site and commit message
  def summarize(agenda, date)
    summary = "- [#{self.formatDate(date)}]" +
       "(../records/minutes/#{date[0..3]}/board_minutes_#{date}.txt)\n"

    agenda.each do |item|
      if item.attach =~ /^7\w$/
        if item.minutes and item.minutes.downcase().include? 'tabled'
          summary += "    * #{item.title.trim()} (tabled)\n"
        else
          summary += "    * #{item.title.trim()}\n"
        end
      end
    end

    @date = date
    @summary = summary
    @message = "Publish #{self.formatDate(date)} minutes"
  end

  # convert date to displayable form
  def formatDate(date)
    months = %w(January February March April May June July August September
      October November December)
    date = Date.new(date.gsub('_', '/'))
    return "#{date.getDate()} #{months[date.getMonth()]} #{date.getYear()+1900}"
  end

  def publish(event)
    data = {
      date: @date,
      summary: @summary,
      message: @message
    }

    @disabled = true
    post 'publish', data do |drafts|
      @disabled = false
      Server.drafts = drafts
      jQuery('#publish-minutes-form').modal(:hide)
      document.body.classList.remove('modal-open')
      # No longer exists
      # window.open('https://cms.apache.org/www/publish', '_blank').focus()
    end
  end
end
