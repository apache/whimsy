#
# Action items.  Link to PMC reports when possible, highlight missing
# action item status updates.
#

class ActionItems < Vue
  def initialize
    @disabled = false
  end

  def self.buttons()
    return [{form: ActionReminder}]
  end

  def render
    first = true

    _section.flexbox do
      _pre.report do
        @@item.actions.each do |action|

          # skip actions that don't match the filter
          if @@filter
            match = true
            @@filter.each_pair do |key, filter|
              match &&= (action[key] == filter)
            end
            next unless match
          end

          # space between items and add help info on top
          if first
            unless @@filter or Minutes.complete
              _p.alert_info 'Click on Status to update'
            end

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
                  '/board/minutes/' +
                  action.pmc.gsub(/\W/, '_') +
                  "#minutes_#{action.date.gsub('-', '_')}"
              end
            end
            _ " ]\n      "

          elsif action.date
            _ "[ #{action.date} ]\n      "
          end

          # launch edit dialog when there is a click on the status
          options = {on: {click: self.updateStatus}, class: ['clickable']}
          options = {} if Minutes.complete
          options.attrs = {}

          # copy action properties to data attributes
          action.each_pair do |name, option|
            options.attrs["data-#{name}"] = option
          end

          # include pending updates
          pending = Pending.find_status(action)
          options.attrs['data-status'] = pending.status if pending

          Vue.createElement('span', options) do
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

        if first
          _p {_em 'Empty'}
        end
      end

      if not first
        # Update action item (hidden form)
        _ModalDialog id: 'updateStatusForm', color: 'commented' do
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

          _button.btn_default 'Cancel', data_dismiss: 'modal',
            disabled: @disabled
          _button.btn_primary 'Save', onClick: self.save,
            disabled: @disabled || (@baseline == @status)
        end
      end
    end

    # Action Items Captured During the Meeting
    if @@item.title == 'Action Items'
      captured = []
      Minutes.actions.each do |action|
        if @@filter
          match = true
          @@filter.each_pair do |key, filter|
            match &&= (action[key] == filter)
          end
          next unless match
        end

        captured << action
      end

      unless captured.empty?
        _section do
          _h3 'Action Items Captured During the Meeting'
          _pre.comment captured do |action|
            # skip actions that don't match the filter
            if @@filter
              match = true
              @@filter.each_pair do |key, filter|
                match &&= (action[key] == filter)
              end
              next unless match
            end

            _ "* #{action.owner}: #{action.text.gsub("\n", "\n        ")}\n"
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
  def mounted()
    jQuery('#updateStatusForm').on 'shown.bs.modal' do
      $refs.statusText.focus()
    end
  end

  # launch update status form when status text is clicked
  def updateStatus(event)
    parent = event.target.parentNode

    # update state from data attributes
    for i in 0...parent.attributes.length
      attr = parent.attributes[i]
      $data[attr.name[5..-1]] = attr.value if attr.name.start_with? 'data-'
    end

    # unindent action
    @status.gsub!(/\n {14}/, "\n")

    # set baseline to current value
    @baseline = @status

    # show dialog
    jQuery('#updateStatusForm').modal(:show)
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
      jQuery('#updateStatusForm').modal(:hide)
      @disabled = false
      Pending.load pending
    end
  end
end
