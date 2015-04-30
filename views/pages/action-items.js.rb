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
    first = true

    updates = Pending.status.keys()

    _pre.report do
      @@item.actions.each do |action|

        # skip actions that don't match the filter
        if @@filter
          match = true
          for key in @@filter
            match &&= (action[key] == @@filter[key])
          end
          next unless match
        end

        # space between items and add help info on top
        if first
          _p.alert_info 'Click on Status to update' unless @@filter
          first = false
        else
          _ "\n"
        end

        # action owner and text
        _ "* #{action.owner}: #{action.text}\n     "

        if action.pmc and not (@@filter and @@filter.title)
          _ '[ '

          # if there is an associated PMC and that PMC is on this month's
          # agenda, link to that report
          item = Agenda.find(action.pmc)
          if item
            _Link text: action.pmc, class: item.color, href: item.href
          elsif action.pmc
            _span.blank action.pmc
          end

          _ " #{action.date}" if action.date
          _ " ]\n     "

        elsif action.date
          _ "[ #{action.date} ]\n     "
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
          text = "#{action.owner}: #{action.text}"
          text += " [ #{action.pmc} ]" if action.pmc
          if updates.include? text
            _span "Status: "
            _em.span.commented "#{Pending.status[text]}\n"
          elsif action.status == ''
            _span.missing 'Status:'
            _ "\n"
          else
            _Text raw: "Status: #{action.status}\n", filters: [hotlink]
          end
        end
      end
    end

    if first
      _p {_em 'Empty'} 
    else
      # Update action item (hidden form)
      _ModalDialog ref: 'updateStatusForm', color: 'commented' do
        _h4 'Update Action Item'

        _p do
          _span @action
          if @pmc
            _ ' [ '
            _span @pmc, class: @color
            _ ' ]'
          end
        end

        _textarea label: 'Status:', value: @status, rows: 5

        _button.bn_default 'Cancel', data_dismiss: 'modal', disabled: @disabled
        _button.btn_primary 'Save', onClick: self.save,
          disabled: @disabled || (@baseline == @status)
      end
    end
  end

  # autofocus on action status in update action form
  def componentDidMount()
    jQuery(~updateStatusForm).on 'shown.bs.modal' do
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
    jQuery(~updateStatusForm).modal(:show)
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
      jQuery(~updateStatusForm).modal(:hide)
      @disabled = false
      Pending.load pending
    end
  end
end
