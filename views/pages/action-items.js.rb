#
# Action items.  Link to PMC reports when possible, highlight missing
# action item status updates.
#

class ActionItems < React
  def initialize
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
        attrs = {onClick: self.updateStatus, className: 'clickable'}

        # copy action properties to data attributes
        for name in action
          attrs["data-#{name}"] = action[name]
        end

        React.createElement('span', attrs) do
          # highlight missing action item status updates
          pending = Pending.find_status(action)
          if pending
            _span "Status: "
            _em.span.commented "#{pending.status}\n"
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
          _span "#@owner: #@text"
          if @pmc
            _ ' [ '
            _span " #@pmc"  if @pmc
            _span " #@date" if @date
            _ ' ]'
          end
        end

        _textarea ref: 'statusText', label: 'Status:', value: @status, rows: 5

        _button.bn_default 'Cancel', data_dismiss: 'modal', disabled: @disabled
        _button.btn_primary 'Save', onClick: self.save,
          disabled: @disabled || (@baseline == @status)
      end
    end
  end

  # autofocus on action status in update action form
  def componentDidMount()
    jQuery(~updateStatusForm).on 'shown.bs.modal' do
      ~statusText.focus()
    end
  end

  # launch update status form when status text is clicked
  def updateStatus(event)
    parent = event.target.parentNode

    # construct action from data attributes
    action = {}
    for i in 0...parent.attributes.length
      attr = parent.attributes[i]
      action[attr.name[5..-1]] = attr.value if attr.name.start_with? 'data-'
    end

    # apply any pending updates to this action
    pending = Pending.find_status(action)
    action.text = pending.action if pending

    # set baseline to current value
    action.baseline = action.status

    # show dialog
    jQuery(~updateStatusForm).modal(:show)

    # update state
    self.setState(action)
  end

  # when save button is pushed, post update and dismiss modal when complete
  def save(event)
    data = {
      agenda: Agenda.file,
      owner: @owner,
      text: @text,
      pmc: @pmc,
      date: @date,
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
