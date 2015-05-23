class AddMinutes < React
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
        _textarea.col_md_7 value: @ai_text, rows: 1, tabIndex: 2
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

      _button.btn_primary 'Save', type: 'button', onClick: self.save,
        disabled: @disabled || @base == @draft
    end
  end

  # autofocus on minute text
  def componentDidMount()
    jQuery('#minute-form').on 'shown.bs.modal' do
      ~'#minute-text'.focus()
    end
  end

  # when initially displayed, set various fields to match the item
  def componentWillMount()
    self.setup(@@item)
  end

  # when item changes, reset various fields to match
  def componentWillReceiveProps(newprops)
    self.setup(newprops.item) if newprops.item.href != self.props.item.href
  end

  # reset base, draft minutes, shepherd, and default ai_text
  def setup(item)
    @base = @draft = Minutes.get(item.title) || ''
    @ai_owner = item.shepherd
    @ai_text = "pursue a report for #{item.title}" unless item.text
  end

  # add an additional AI to the draft minutes for this item
  def addAI(event)
    @draft += "\n" if @draft
    @draft += "@#{@ai_owner}: #{@ai_text}"
    @ai_owner = @@item.shepherd
    @ai_text = ''
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
      text: text
    }

    @disabled = true
    post 'minute', data do |minutes|
      Minutes.load minutes
      self.setup(@@item)
      @disabled = false
      jQuery('#minute-form').modal(:hide)
    end
  end
end
