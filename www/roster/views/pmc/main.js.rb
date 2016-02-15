#
# Show a PMC
#

class PMC < React
  def render
    auth = (@@auth.id == @committee.chair or @@auth.secretary or @@auth.root)

    # header
    _h1 do
      _a @committee.display_name, href: @committee.site
      _small " established #{@committee.established}" if @committee.established
    end

    _p @committee.description

    if auth
      _div.alert.alert_success 'Double click on a row to edit.  ' +
        "Double click on \u2795 to add."
    end

    # main content
    _PMCMembers auth: auth, committee: @committee
    _PMCCommitters auth: auth, committee: @committee

    # hidden form
    _PMCConfirm pmc: @committee.id, update: self.update if auth
  end

  # capture committee on initial load
  def componentWillMount()
    @committee = @@committee
  end

  # capture committee on subsequent loads
  def componentWillReceiveProps()
    @committee = @@committee
  end

  # update committee from conformation form
  def update(committee)
    @committee = committee
  end
end
