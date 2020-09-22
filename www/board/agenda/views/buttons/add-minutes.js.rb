class AddMinutes < Vue
  def initialize
    @disabled = false
  end

  # default attributes for the button associated with this form
  def self.button
    {
      text: 'add minutes',
      class: 'btn_primary',
      data_toggle: 'modal',
      data_target: '#minute-form'
    }
  end

  def render
    _ModalDialog.minute_form!.wide_form color: 'commented' do
      _h4.commented 'Minutes'

      # either a large text area, or a slightly smaller text area
      # followed by comments
      if @@item.comments.empty?
        _textarea.minute_text!.form_control rows: 17, tabIndex: 1,
          placeholder: 'minutes', value: @draft
      else
        _textarea.minute_text!.form_control rows: 12, tabIndex: 1,
          placeholder: 'minutes', value: @draft

        _h3 'Comments'
        _div.minute_comments! @@item.comments do |comment|
          _pre.comment comment
        end
      end

      # action items
      _div.row style: {marginTop: '1em'} do
        _button.btn.btn_sm.btn_info.col_md_offset_1.col_md_1 '+ AI',
          onClick: self.addAI, disabled: !@ai_owner || !@ai_text
        _label.col_md_2 do
          _select Minutes.attendee_names, value: @ai_owner do |name|
            _option name
          end
        end
        _textarea.col_md_7 value: @ai_text, rows: 1, cols: 40, tabIndex: 2
      end

      if @@item.attach =~ /^[A-Z]+$/
        _input.flag! type: 'checkbox',
          label: 'report was not accepted',
          onClick: self.reject, checked: @checked
      end

      # variable number of buttons
      _button.btn_default 'Cancel', type: 'button', data_dismiss: 'modal',
        onClick:-> {@draft = @base}

      if @base
        _button.btn_warning 'Delete', type: 'button',
          onClick:-> {@draft = ''}
      end

      # special buttons for prior months draft minutes
      if @@item.attach =~ /^3\w/
        _button.btn_warning 'Tabled', type: 'button',
          onClick: self.save, disabled: @disabled
        _button.btn_success 'Approved', type: 'button',
          onClick: self.save, disabled: @disabled
      end

      _button 'Reflow', class: self.reflow_color(), onClick: self.reflow
      _button.btn_primary 'Save', type: 'button', onClick: self.save,
        disabled: @disabled || @base == @draft
    end
  end

  def mounted()
    # update form to match current item
    jQuery('#minute-form').on 'show.bs.modal' do
      self.setup(@@item)
    end

    # autofocus on minute text
    jQuery('#minute-form').on 'shown.bs.modal' do
      document.getElementById("minute-text").focus()
    end
  end

  # when initially displayed, set various fields to match the item
  def created()
    self.setup(@@item)
  end

  # reset base, draft minutes, shepherd, default ai_text, and indent
  def setup(item)
    @base = draft = Minutes.get(item.title) || ''
    if item.attach =~ /^(8|9|1\d)\.$/
      draft ||= item.text
    else
      @ai_text = "pursue a report for #{item.title}" unless item.text
    end
    @draft = draft
    @ai_owner = item.shepherd
    @indent = (@@item.attach =~ /^\w+$/ ? 8 : 4)
    @checked = @@item.rejected
  end

  # add an additional AI to the draft minutes for this item
  def addAI(event)
    @draft += "\n" if @draft
    @draft += "@#{@ai_owner}: #{@ai_text}"
    @ai_owner = @@item.shepherd
    @ai_text = ''
  end

  # determine if reflow button should be default or danger color
  def reflow_color()
    width = 78 - @indent

    if not @draft or @draft.split("\n").all? {|line| line.length <= width}
      return 'btn-default'
    else
      return'btn-danger'
    end
  end

  def reflow()
    @draft = Flow.text(@draft || '', ' ' * @indent)
  end

  def save(event)
    case event.target.textContent
    when 'Save'
      text = @draft
    when 'Tabled'
      text = 'tabled'
    when 'Approved'
      text = 'approved'
    end

    data = {
      agenda: Agenda.file,
      title: @@item.title,
      text: text,
      reject: @checked
    }

    @disabled = true
    post 'minute', data do |minutes|
      Minutes.load minutes
      self.setup(@@item)
      @disabled = false
      jQuery('#minute-form').modal(:hide)
      document.body.classList.remove('modal-open')
    end
  end

  def reject(event)
    @checked = ! @checked

    data = {
      agenda: Agenda.file,
      title: @@item.title,
      text: @base,
      reject: @checked
    }

    post 'minute', data do |minutes|
      Minutes.load minutes
    end
  end
end
