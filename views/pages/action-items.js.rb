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

    _section.flexbox do
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
          _ "* #{action.owner}: #{action.text}\n      "

          if action.pmc and not (@@filter and @@filter.title)
            _ '[ '

            # if there is an associated PMC and that PMC is on this month's
            # agenda, link to the current report, if reporting this month
            item = Agenda.find(action.pmc)
            if item
              _Link text: action.pmc, class: item.color, href: item.href
            elsif action.pmc
              _span.blank action.pmc
            end

            # link to the original report
            if action.date
              _ ' '
              agenda = "board_agenda_#{action.date.gsub('-', '_')}.txt"
              if Server.agendas.include? agenda
                _a action.date, 
                  href: "../#{action.date}/#{action.pmc.gsub(/\W/, '-')}"
              else
                _a action.date, href: 
                  'https://whimsy.apache.org/board/minutes/' +
                  action.pmc.gsub(/\W/, '_') +
                  "#minutes_#{action.date.gsub('-', '_')}"
              end
            end
            _ " ]\n      "

          elsif action.date
            _ "[ #{action.date} ]\n      "
          end

          # launch edit dialog when there is a click on the status
          attrs = {onClick: self.updateStatus, className: 'clickable'}

          # copy action properties to data attributes
          for name in action
            attrs["data-#{name}"] = action[name]
          end

          # include pending updates
          pending = Pending.find_status(action)
          attrs['data-status'] = pending.status if pending

          React.createElement('span', attrs) do
            # highlight missing action item status updates
            if pending
              _span "Status: "
              pending.status.split("\n").each do |line|
                match = line.match(/^( *)(.*)/)
                _span match[1]
                _em.commented "#{match[2]}\n"
              end
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

          _button.bn_default 'Cancel', data_dismiss: 'modal',
            disabled: @disabled
          _button.btn_primary 'Save', onClick: self.save,
            disabled: @disabled || (@baseline == @status)
        end
      end

      actions = Minutes.actions
      unless actions.empty?
        _section do
          _h3 'Action Items Captured During the Meeting'
          _pre.comment actions do |action|
            _ "* #{action.owner}: #{action.text}\n"
            _ "      [ "
            if action.item
              _Link text: action.item.title, href: action.item.href,
                class: action.item.color
            end
            _ " #{Agenda.title} ]\n\n"
          end
        end
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

    # unindent action
    action.status.gsub!(/\n {14}/, "\n")

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
