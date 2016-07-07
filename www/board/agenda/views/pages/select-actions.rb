#
# Action items.  Link to PMC reports when possible, highlight missing
# action item status updates.
#

class SelectActions < React
  def self.buttons()
    return [{button: PostActions}]
  end

  def initialize
    SelectActions.list = []
    @names = []
  end

  def render
    _h3 'Post Action Items'

    _p.alert_info 'Action Items have yet to be posted. '+
      'Unselect the ones below that have been completed. ' +
      'Click on the "post actions" button when done.'

    _pre.report do
      SelectActions.list.each do |action|
        _CandidateAction action: action, names: @names
      end
    end
  end

  def componentDidMount()
    retrieve 'potential-actions', :json do |response|
      if response
        SelectActions.list = response.actions
        @names = response.names
      end
    end
  end
end

class CandidateAction < React
  def render
    _input type: 'checkbox', checked: !@@action.complete,
      onChange:-> {@@action.complete = !@@action.complete; self.forceUpdate()}
    _span " "
    _span @@action.owner
    _span ": "
    _span @@action.text
    _span "\n      [ #{@@action.pmc} #{@@action.date} ]\n      "
    if @@action.status
      _Text raw: "Status: #{@@action.status}\n", filters: [hotlink]
    end
    _span "\n"
  end
end
