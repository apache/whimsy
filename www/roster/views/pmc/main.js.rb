#
# Show a PMC
#

class PMC < React
  def initialize
    @attic = nil
  end

  def render
    auth = (@@auth.id == @committee.chair or @@auth.secretary or @@auth.root)

    # add jump links to main sections of page
    _div.breadcrumbs do
      _a 'PMC', :href => "committee/#{@committee[:id]}#pmc"
      _span " \u00BB "
      _a 'Mail Moderators', :href => "committee/#{@committee[:id]}#mail"
      _span " \u00BB "
      _a 'Reporting Schedule', :href => "committee/#{@committee[:id]}#reporting"
    end

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
      _div.alert.alert_success do
        _span 'Double click on a row to edit.'
        unless @committee.roster.keys().empty?
          _span "  Click on \u2795 to add."
        end
      end
    end

    # main content
    _PMCMembers auth: auth, committee: @committee
    _PMCCommitters auth: auth, committee: @committee

    # mailing lists
    if @committee.moderators
      _h2.mail! 'Mail list moderators'
      _table do
        _thead do
          _tr do
            _th 'list name'
            _th 'moderators'
          end
        end
        _tbody do
          for list_name in @committee.moderators
            _tr do
              _td do
                _a list_name, href: 'https://lists.apache.org/list.html?' +
                  list_name
              end
              _td @committee.moderators[list_name].join(', ')
            end
          end
        end
      end
    else
      _h2.mail! 'Mail lists'
      _ul do
        for mail_name in @committee.mail
          parsed = mail_name.match(/^(.*?)-(.*)/)
          list_name = "#{parsed[2]}@#{parsed[1]}.apache.org"
          _li do
            _a list_name, href: 'https://lists.apache.org/list.html?' +
              list_name
          end
        end
      end
    end

    # reporting schedule
    _h2.reporting! 'Reporting Schedule'
    _ul do
      _li @committee.report

      if @committee.schedule and @committee.schedule != @committee.report
        _li @committee.schedule 
      end

      _li do
        _a 'Prior reports', href: 'https://whimsy.apache.org/board/minutes/' +
          @committee.display_name.gsub(/\s+/, '_')
      end

      if @committee.ldap[@@auth.id] or @@auth.member
        _li do
          _a 'Apache Committee Report Helper',
            href: "https://reporter.apache.org/?#{@committee.id}"
        end
      end
    end

    # hidden form
    if auth
      _Confirm action: :committee, project: @committee.id, update: self.update
    end
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

      Polyfill.require(%w(Promise fetch)) do
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
end
