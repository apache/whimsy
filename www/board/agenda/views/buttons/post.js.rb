#
# Post or edit a report or resolution
#
# For new resolutions, allow entry of title, but not commit message
# For everything else, allow modification of commit message, but not title

class Post < Vue
  def initialize
    @button = @@button.text
    @disabled = false
    @alerted = false
    @edited = false
  end

  # default attributes for the button associated with this form
  def self.button
    {
      text: 'post report',
      class: 'btn_primary',
      disabled: Server.offline,
      data_toggle: 'modal',
      data_target: '#post-report-form'
    }
  end

  def selectItem(event)
    @button = event.target.textContent
    retitle()
  end

  def render
    _ModalDialog.wide_form.post_report_form! color: 'commented' do
      if @button == 'add item'
        _h4 'Select Item Type'
  
        _ul.new_item_type do
          _li do
            _button.btn.btn_primary 'Change Chair', disabled: true
          end
  
          _li do
            _button.btn.btn_primary 'Establish Project', disabled: true
          end
  
          _li do
            _button.btn.btn_primary 'Terminate Project', disabled: true
          end
  
          _li do
            _button.btn.btn_primary 'Out of Cycle Report', disabled: true
          end
  
          _li do
            _button.btn.btn_primary 'New Resolution', onClick: selectItem
            _span '- free form entry of a new resolution'
          end
        end
  
        _button.btn_default 'Cancel', data_dismiss: 'modal'
      else
        _h4 @header

        #input field: title
        if @header == 'Add Resolution'
          _input.post_report_title! label: 'title', disabled: @disabled,
            placeholder: 'title', value: @title, onFocus: self.default_title
        end

        #input field: report text
        _textarea.post_report_text! label: @label, value: @report,
          placeholder: @label, rows: 17, disabled: @disabled, 
          onInput: self.change_text

        # upload of spreadsheet from virtual
        if @@item.title == 'Treasurer'
          _form do
            _div.form_group do
              _label 'financial spreadsheet from virtual', for: 'upload'
              _input.upload! type: 'file', value: @upload
              _button.btn.btn_primary 'Upload', onClick: upload_spreadsheet,
                disabled: @disabled || !@upload
            end
          end
        end

        #input field: commit_message
        if @header != 'Add Resolution'
          _input.post_report_message! label: 'commit message', 
            disabled: @disabled, value: @message
        end

        # footer buttons
        _button.btn_default 'Cancel', data_dismiss: 'modal', disabled: @disabled
        _button 'Reflow', class: self.reflow_color(), onClick: self.reflow
        _button.btn_primary 'Submit', onClick: self.submit, 
          disabled: (not self.ready())
      end
    end
  end

  # autofocus on report/resolution title/text
  def mounted()
    jQuery('#post-report-form').on 'show.bs.modal' do
      # update contents when modal is about to be shown
      @button = @@button.text
      self.retitle()
    end

    jQuery('#post-report-form').on 'shown.bs.modal' do
      reposition()
    end
  end

  # reposition after update if header changed
  def updated()
    reposition() if Post.header != @header
  end

  # set focus, scroll
  def reposition()
    # set focus once modal is shown
    title = document.getElementById("post-report-title")
    text = document.getElementById("post-report-text")

    if title || text
      (title || text).focus()

      # scroll to the top
      setTimeout 0 do
        text.scrollTop = 0 if text
      end
    end

    Post.header == @header
  end

  # initialize form title, etc.
  def created()
    self.retitle()
  end

  # match form title, input label, and commit message with button text
  def retitle()
    case @button
    when 'post report'
      @header = 'Post Report'
      @label = 'report'
      @message = "Post #{@@item.title} Report"

    when 'edit report'
      @header = 'Edit Report'
      @label = 'report'
      @message = "Edit #{@@item.title} Report"

    when 'add resolution', 'New Resolution'
      @header = 'Add Resolution'
      @label = 'resolution'
      @title = ''

    when 'edit resolution'
      @header = 'Edit Resolution'
      @label = 'resolution'
      @message = "Edit #{@@item.title} Resolution"

    when 'post items'
      @header = 'Post Discussion Items'
      @label = 'items'
      @message = "Post Discussion Items"

    when 'edit items'
      @header = 'Edit Discussion Items'
      @label = 'items'
      @message = "Edit Discussion Items"
    end

    if not @edited
      text = @@item.text || '' 
      if @@item.title == 'President'
        text.sub! /\s*Additionally, please see Attachments \d through \d\./, ''
      end

      @report = text
      @digest = @@item.digest
      @alerted = false
      @edited = false
      @base = @report
    elsif not @alerted and @edited and @digest != @@item.digest
      alert 'edit conflict'
      @alerted = true
    else
      @report = @base
    end

    if @header == 'Add Resolution' or @@item.attach =~ /^[47]/
      @indent = '        '
    elsif @@item.attach == '8.'
      @indent = '    '
    else
      @indent = ''
    end
  end

  # default title based on common resolution patterns
  def default_title(event)
    return if @title
    match = nil

    if (match = @report.match(/appointed\s+to\s+the\s+office\s+of\s+Vice\s+President,\s+Apache\s+(.*?),/))
      @title = "Change the Apache #{match[1]} Project Chair"
    elsif (match = @report.match(/to\s+be\s+known\s+as\s+the\s+"Apache\s+(.*?)\s+Project",\s+be\s+and\s+hereby\s+is\s+established/))
      @title = "Establish the Apache #{match[1]} Project"
    elsif (match = @report.match(/the\s+Apache\s+(.*?)\s+project\s+is\s+hereby\s+terminated/))
      @title = "Terminate the Apache #{match[1]} Project"
    end
  end

  # track changes to text value
  def change_text(event)
    @report = event.target.value
    self.change_message()
  end

  # update default message to reflect whether only whitespace changes were
  # made or if there is something more that was done
  def change_message()
    @edited = (@base != @report)

    if @message =~ /(Edit|Reflow) #{@@item.title} Report/
      if @edited and @base.gsub(/[ \t\n]+/, '') == @report.gsub(/[ \t\n]+/, '')
         @message = "Reflow #{@@item.title} Report"
      else
         @message = "Edit #{@@item.title} Report"
      end
    end
  end

  # determine if reflow button should be default or danger color
  def reflow_color()
    width = 80 - @indent.length

    if @report.split("\n").all? {|line| line.length <= width}
      return 'btn-default'
    else
      return'btn-danger'
    end
  end

  # perform a reflow of report text
  def reflow()
    report = @report
    textarea = document.getElementById('post-report-text')
    indent = start = finish = 0

    # extract selection (if any)
    if textarea and textarea.selectionEnd > textarea.selectionStart
      start = textarea.selectionStart
      start -= 1  while start > 0 and report[start-1] != "\n"
      finish = textarea.selectionEnd
      finish += 1 while report[finish] != '\n' and finish < report.length-1
    end

    # remove indentation
    unless report =~ /^\S/
      regex = RegExp.new('^( +)', 'gm')
      indents = []
      while (result = regex.exec(report))
        indents.push result[1].length
      end
      unless indents.empty?
        indent = Math.min(*indents)
        report.gsub!(RegExp.new('^' + ' ' * indent, 'gm'), '')
      end
    end

    # enable special punctuation rules for the incubator
    puncrules = (@@item.title == 'Incubator')

    # reflow selection or entire report
    if finish > start
      report = Flow.text(report[start..finish], @indent+indent, puncrules)
      report.gsub(/^/, ' ' * indent) if indent > 0
      @report = @report[0...start] + report + @report[finish+1..-1]
    else
      @report = Flow.text(report, @indent, puncrules)
    end

    self.change_message()
  end

  # determine if the form is ready to be submitted
  def ready()
    return false if @disabled

    if @header == 'Add Resolution'
      return @report != '' && @title != ''
    else
      return @report != @@item.text && @message != ''
    end
  end

  # upload contents of spreadsheet in base64; append extracted table to report
  def upload_spreadsheet(event)
    @disabled = true
    event.preventDefault()

    reader = FileReader.new
    def reader.onload(event)
      result = event.target.result
      base64 = btoa(String.fromCharCode(*Uint8Array.new(result)))
      post 'financials', spreadsheet: base64 do |response|
        report = @report
        report += "\n" if report and not report.end_with? "\n"
        report += "\n" if report
        report += response.table

        self.change_text target: {value: report}

        @upload = nil
        @disabled = false
      end
    end
    reader.readAsArrayBuffer(document.getElementById('upload').files[0])
  end

  # when save button is pushed, post comment and dismiss modal when complete
  def submit(event)
    @edited = false

    if @header == 'Add Resolution'
      data = {
        agenda: Agenda.file,
        attach: '7?',
        title: @title,
        report: @report
      }
    else
      data = {
        agenda: Agenda.file,
        attach: @@item.attach,
        digest: @digest,
        message: @message,
        report: @report
      }
    end

    @disabled = true
    post 'post', data do |response|
      jQuery('#post-report-form').modal(:hide)
      document.body.classList.remove('modal-open')
      @disabled = false
      Agenda.load response.agenda, response.digest
    end
  end
end
