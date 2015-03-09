#
# Action items.  Link to PMC reports when possible, highlight missing
# action item status updates.
#

class ActionItems < React
  def render
    _pre.report do
      @actions.each do |action|
        _ action.text

        # if there is an associated PMC and that PMC is on this month's
        # agenda, link to that report
        if action.item
          _Link text: action.pmc, class: action.item.color, 
            href: action.item.href
        elsif action.pmc
          _span.blank action.pmc
        end

        # highlight missing action item status updates
        if action.missing
          _span.commented action.status
          _ "\n"
        else
          _ "#{action.status}\n"
        end
      end
    end
  end

  # parse actions on first load
  def componentWillMount()
    self.componentWillReceiveProps(self.props)
  end

  # parse actions into text, pmc, status;
  # set missing flag if status is empty;
  # find item associated with PMC if reporting this month
  def componentWillReceiveProps(props)
    @actions = props.item.actions.text.split(/^\n\* /m).map do |text|
      match1 = text.match(/((?:\n|.)*?)(\n\s*Status:(?:\n|.)*)/)
      match2 = match1[1].match(/((?:\n|.)*?)(\[ (\S*) \])?\s*$/)

      {
        text: "* " + match2[1],
        status: match1[2],
        missing: match1[2] =~ /Status:\s*$/,
        pmc: match2[2],
        item: match2[3] ? Agenda.find(match2[3]) : nil
      }
    end
  end
end
