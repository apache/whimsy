#
# Post or edit a report or resolution
#
# For new resolutions, allow entry of title, but not commit message
# For everything else, allow modification of commit message, but not title

class Post < React
  def initialize
    @disabled = false
  end

  # default attributes for the button associated with this form
  def self.button
    {
      text: 'post report',
      class: 'btn_primary',
      data_toggle: 'modal',
      data_target: '#post-report-form'
    }
  end

  def render
    # determine if reflow button should be default or danger color
    width = 80 - @indent.length
    if @report.split("\n").all? {|line| line.length <= width}
      reflow_class = 'btn-default'
    else
      reflow_class = 'btn-danger'
    end

    _ModalDialog.wide_form.post_report_form! color: 'commented' do
      _h4 @title

      #input field: title
      if @@button.text == 'add resolution'
        _input.post_report_title! label: 'title', disabled: @disabled,
          placeholder: 'title'
      end

      #input field: report text
      _textarea.post_report_text! label: @label, value: @report,
        placeholder: @label, rows: 17, disabled: @disabled, 
        onChange: self.change

      #input field: commit_message
      if @@button.text != 'add resolution'
        _input.post_report_message! label: 'commit message', 
          disabled: @disabled, defaultValue: @message
      end

      # footer buttons
      _button.btn_default 'Cancel', data_dismiss: 'modal', disabled: @disabled
      _button 'Reflow', class: reflow_class, onClick: self.reflow
      _button.btn_primary 'Submit', onClick: self.submit, disabled: @disabled
    end
  end

  # set properties on initial load
  def componentWillMount()
    self.componentWillReceiveProps()
  end

  # autofocus on report/resolution title/text
  def componentDidMount()
    jQuery('#post-report-form').on 'shown.bs.modal' do
      if @@button.text == 'add resolution'
        ~'#post-report-title'.focus()
      else
        ~'#post-report-text'.focus()
      end
    end
  end

  # match form title, input label, and commit message with button text
  def componentWillReceiveProps(newprops)
    case @@button.text
    when 'post report'
      @title = 'Post Report'
      @label = 'report'
      @message = "Post #{@@item.title} Report"

    when 'edit report'
      @title = 'Edit Report'
      @label = 'report'
      @message = "Edit #{@@item.title} Report"

    when 'add resolution'
      @title = 'Add Resolution'
      @label = 'resolution'

    when 'edit resolution'
      @title = 'Edit Resolution'
      @label = 'resolution'
      @message = "Edit #{@@item.title} Resolution"
    end

    @indent = (@@item.attach =~ /^4/ ? '        ' : '')

    if !self.state.item or newprops.item.attach != self.state.item.attach
      @report = @@item.text || '' 
    end
  end

  # track changes to input value; change color of reflow button when
  # there is a need for a reflow.
  def change(event)
    @report = event.target.value
  end

  # reflow
  def reflow()
    @report = Flow.text(@report, @indent)
  end

  # when save button is pushed, post comment and dismiss modal when complete
  def submit(event)
    if @@button.text == 'add resolution'
      data = {
        agenda: Agenda.file,
        attach: '7?',
        title: ~'#post-report_title'.value,
        report: ~'#post-report-text'.value
      }
    else
      data = {
        agenda: Agenda.file,
        attach: @@item.attach,
        digest: @@item.digest,
        message: ~'#post-report-message'.value,
        report: ~'#post-report-text'.value
      }
    end

    @disabled = true
    post 'post', data do |response|
      jQuery('#post-report-form').modal(:hide)
      @disabled = false
      Agenda.load response.agenda
    end
  end
end
