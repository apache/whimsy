#
# Action items.  Link to PMC reports when possible, highlight missing
# action item status updates.
#

class ActionItems < React
  def initialize
    @action = ''
    @status = ''
    @baseline = ''
    @disabled = false
  end

  def render
    if @@item.text
      _p.alert_info 'Click on Status to update'

      updates = Pending.status.keys()

      _pre.report do
        @actions.each do |action|
          _ "* #{action.text}"

          # if there is an associated PMC and that PMC is on this month's
          # agenda, link to that report
          if action.item
            _Link text: action.pmc, class: action.item.color, 
              href: action.item.href
          elsif action.pmc
            _span.blank action.pmc
          end

          # launch edit dialog when there is a click on the status
          _span.clickable(
            data_action: action.text,
            data_status: action.status,
            data_pmc: action.pmc,
            data_color: action.item ? action.item.color : 'blank',
            onClick: self.updateStatus
          ) do
            # highlight missing action item status updates
            text = action.text
            text += action.pmc if action.pmc
            if updates.include? text
              _span "\n      Status: "
              _em.span.commented Pending.status[text]
              _span "\n\n"
            elsif action.missing
              _span.commented action.status
              _ "\n"
            else
              _Text raw: "#{action.status}\n", filters: [hotlink]
            end
          end
        end
      end
    else
      _p {_em 'Empty'} 
    end

    # Update action item (hidden form)
    _ModalDialog.update_action_form! color: 'commented' do
      _h4 'Update Action Item'

      _p do
        _span @action
        _span @pmc, class: @color if @pmc
      end

      _textarea.action_status! label: 'Status:', value: @status, rows: 5

      _button.btn_default 'Cancel', data_dismiss: 'modal', disabled: @disabled
      _button.btn_primary 'Save', onClick: self.save,
        disabled: @disabled || (@baseline == @status)
    end
  end

  # parse actions on first load
  def componentWillMount()
    self.componentWillReceiveProps()
  end

  # parse actions into text, pmc, status;
  # set missing flag if status is empty;
  # find item associated with PMC if reporting this month
  def componentWillReceiveProps()
    if @@item.text
      @actions = @@item.text.sub(/^\* /, '').split(/^\n\* /m).map do |text|
        match1 = text.match(/((?:\n|.)*?)(\n\s*Status:(?:\n|.)*)/)
        match2 = match1[1].match(/((?:\n|.)*?)(\[ (\S*) \])?\s*$/)

        {
          text: match2[1],
          status: match1[2],
          missing: match1[2] =~ /Status:\s*$/,
          pmc: match2[2],
          item: match2[3] ? Agenda.find(match2[3]) : nil
        }
      end
    else
      @actions = []
    end
  end

  # autofocus on action status in update action form
  def componentDidMount()
    jQuery('#update-action-form').on 'shown.bs.modal' do
      document.getElementById('action-status').focus()
    end
  end

  # launch update status form when status text is clicked
  def updateStatus(event)
    parent = event.target.parentNode
    @action = parent.getAttribute('data-action')
    @pmc = parent.getAttribute('data-pmc')
    @color = parent.getAttribute('data-color')
    @status = Pending.status[@action + @pmc] ||
      parent.getAttribute('data-status').trim().
        sub('Status:', '').gsub(/^\s+/m, '').gsub(/\n(\S)/, ' $1')
    @baseline = @status
    jQuery('#update-action-form').modal(:show)
  end

  # when save button is pushed, post update and dismiss modal when complete
  def save(event)
    data = {
      agenda: Agenda.file,
      action: @action,
      pmc: @pmc,
      status: @status
    }

    @disabled = true
    post 'status', data do |pending|
      jQuery('#update-action-form').modal(:hide)
      @disabled = false
      Pending.load pending
    end
  end
end
