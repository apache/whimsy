class Vote < Vue
  def initialize
    @disabled = false
  end

  # default attributes for the button associated with this form
  def self.button
    {
      text: 'vote',
      class: 'btn_primary',
      data_toggle: 'modal',
      data_target: '#vote-form'
    }
  end

  def render
    _ModalDialog.vote_form!.wide_form color: 'commented' do
      _h4.commented 'Vote'

      _p do
        _span "#{@votetype} vote on the matter of "
        _em @@item.fulltitle.sub(/^Resolution to/, '')
      end

      _pre @directors

      _textarea.vote_text! rows: 4, placeholder: 'minutes', value: @draft

      _button.btn_default 'Cancel', type: 'button', data_dismiss: 'modal',
        onClick:-> {@draft = @base}

      if @base
        _button.btn_warning 'Delete', type: 'button', onClick: self.save
      end

      _button.btn_primary 'Save', type: 'button', onClick: self.save,
        disabled: (@draft == @base)

      _button.btn_warning 'Tabled', type: 'button',
        onClick: self.save, disabled: (@draft != '')

      _button.btn_success 'Unanimous', type: 'button',
        onClick: self.save, disabled: (@draft != '')
    end
  end

  # when initially displayed, set various fields to match the item
  def created()
    self.setup(@@item)
  end

  def mounted()
    # update form to match current item
    jQuery('#vote-form').on 'show.bs.modal' do
      self.setup(@@item)
    end

    # autofocus on comment text
    jQuery('#vote-form').on 'shown.bs.modal' do
      document.getElementById("vote-text").focus()
    end
  end


  # reset base, draft minutes, directors present, and vote type
  def setup(item)
    @directors = Minutes.directors_present

    # alternate forward/reverse roll calls based on month and attachment
    month = Date.new(Date.parse(Agenda.date)).getMonth()
    attach = item.attach.charCodeAt(1)
    if (month + attach) % 2 == 0
      @votetype = "Roll call"
    else
      @votetype = "Reverse roll call"
      @directors = @directors.split("\n").reverse().join("\n")
    end

    @base = @draft = Minutes.get(item.title) || ''
  end

  # post vote results
  def save(event)
    case event.target.textContent
    when 'Save'
      text = @draft
    when 'Delete'
      text = ''
    when 'Tabled'
      text = 'tabled'
    when 'Unanimous'
      text = 'unanimous'
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
      jQuery('#vote-form').modal(:hide)
      document.body.classList.remove('modal-open')
    end
  end
end
