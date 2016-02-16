#
# Show a PMC
#

class PMC < React
  def initialize
    @attic = nil
  end

  def render
    auth = (@@auth.id == @committee.chair or @@auth.secretary or @@auth.root)

    # header
    _h1 do
      _a @committee.display_name, href: @committee.site
      _small " established #{@committee.established}" if @committee.established
    end

    _p @committee.description

    # link to attic resolutions
    if not @committee.established and @attic
      for id in @attic
        next unless @attic[id] =~ /\b#{@committee.id}\b/i

        _div.alert.alert_danger do
          _a "#{id}: #{@attic[id]}", 
            href: "https://issues.apache.org/jira/browse/#{id}"
        end
      end
    end

    # usage information for authenticated users (PMC chair, etc.)
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
    self.update(@@committee)
  end

  # capture committee on subsequent loads
  def componentWillReceiveProps()
    self.update(@@committee)
  end

  # update committee from conformation form
  def update(committee)
    @committee = committee

    if @attic == nil and not committee.established and defined? fetch
      @attic = []

      fetch('attic/issues.json', credentials: 'include').then {|response|
        if response.status == 200
          response.json().then do |json|
            @attic = json
          end
        else
          console.log "Attic JIRA #{response.status} #{response.statusText}"
        end
      }.catch {|error|
        console.log "Attic JIRA #{errror}"
      }
    end
  end
end
