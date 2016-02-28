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

    _h2 'Mail lists'
    _ul do
      for name in @committee.mail
        _li do
          if @committee.mail[name] == 'public'
            _a name, href: "http://mail-archives.apache.org/mod_mbox/#{name}/"
          elsif @@committee.roster[@@auth.id]
            _a name, href: 
              "https://mail-search.apache.org/pmc/private-arch/#{name}/"
          else
            _a name, href: 
              "https://mail-search.apache.org/members/private-arch/#{name}/"
          end
        end
      end
    end

    # reporting schedule
    _h2 'Reporting Schedule'
    _ul do
      _li @committee.report

      if @committee.schedule and @committee.schedule != @committee.report
        _li @committee.schedule 
      end

      _li do
        _a 'Prior reports', href: 'https://whimsy.apache.org/board/minutes/' +
          @committee.display_name.gsub(/\s+/, '_')
      end
    end

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
