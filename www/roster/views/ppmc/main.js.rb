#
# Show a PPMC
#

class PPMC < React
  def initialize
    @create_disabled = false
  end

  def render
    if @@auth
      @@auth.ppmc = @@auth.member or @ppmc.owners.include? @@auth.id
      @@auth.ipmc ||= @@auth.member
    end

    # add jump links to main sections of page
    _div.breadcrumbs do
      _a 'PPMC', :href => "ppmc/#{@ppmc.id}#ppmc"
      _span " \u00BB "
      _a 'Mail Moderators', :href => "ppmc/#{@ppmc.id}#mail"
      _span " \u00BB "
      _a 'Reporting Schedule', :href => "ppmc/#{@ppmc.id}#reporting"
      _span " \u00BB "
      _a 'Status', :href => "ppmc/#{@ppmc.id}#podlingStatus"
    end

    # header
    _h1 do
      _a @ppmc.display_name, 
        href: "https://incubator.apache.org/projects/#{@ppmc.id}.html"
      _small " established #{@ppmc.established}" if @ppmc.established
    end

    _p @ppmc.description

    # usage information for authenticated users (PMC chair, etc.)
    if @@auth.ppmc or @@auth.ipmc
      _div.alert.alert_success do
        if (@@auth.ppmc and @@auth.ipmc) or @@auth.root or @@auth.secretary
          _span 'Double click on a row to show actions.'
        elsif @@auth.ppmc
          _span 'Double click on a PPMC or Committers row to show actions.'
        else
          _span 'Double click on a Mentors row to show actions.'
        end

        unless @ppmc.roster.keys().empty?
          _span "  Click on \u2795 to add."
          _span "  Multiple people can be added with a single confirmation."
        end
      end
    end

    if @ppmc.owners.empty? and (@@auth.root or @@auth.secretary)
      _button.btn.btn_primary 'Create project in LDAP', onClick: self.post,
        disabled: @create_disabled
    end

    # main content
    _PPMCMentors auth: @@auth, ppmc: @ppmc
    _PPMCMembers auth: @@auth, ppmc: @ppmc
    _PPMCCommitters auth: @@auth, ppmc: @ppmc

    # mailing lists
    if @ppmc.moderators
      _h2.mail! 'Mailing list moderators'
      _table do
        _thead do
          _tr do
            _th 'list name'
            _th 'moderators'
          end
        end
        _tbody do
          for list_name in @ppmc.moderators
            _tr do
              _td do
                _a list_name, href: 'https://lists.apache.org/list.html?' +
                  list_name
              end
              _td @ppmc.moderators[list_name].join(', ')
            end
          end
        end
      end
    else
      _h2.mail! 'Mailing lists'
      _ul do
        for mail_name in @ppmc.mail
          parsed = mail_name.match(/^(.*?)-(.*)/)
          mail_list = "#{parsed[2]}@#{parsed[1]}.apache.org"
          _li do
            _a mail_list, href: 'https://lists.apache.org/list.html?' +
              mail_list
          end
        end
      end
    end

    _h2.podlingStatus! 'Podling Status'
    _h3 'Information'
    _ul do
      _li do
        _a 'Podling Proposal', href: @ppmc.podlingStatus.proposal if @ppmc.podlingStatus.proposal
      end
      _li "Incubating for "+@ppmc.duration+" days"
      _li do
        _a 'Prior Board Reports', href: '/board/minutes/' +
            @ppmc.display_name.gsub(/\s+/, '_')
      end
    end
    # infra styled resources
    _h3 'Resources'
    _ul do
      _li do
        _a "GitHub", href: 'https://github.com/apache?q=incubator-' + @ppmc.id
      end if @ppmc.podlingStatus.sourceControl == 'github'
      _li do
        _a "Git Repositories", href: 'https://git-wip-us.apache.org/repos/asf?s=incubator-' + @ppmc.id
      end if !@ppmc.podlingStatus.sourceControl || @ppmc.podlingStatus.sourceControl == 'git' || @ppmc.podlingStatus.sourceControl == 'asfgit'
      _li do
        _a 'https://issues.apache.org/jira/browse/' + @ppmc.podlingStatus.jira,href: 'https://issues.apache.org/jira/browse/' + @ppmc.podlingStatus.jira
      end if @ppmc.podlingStatus.jira
      _li do
        _a 'https://cwiki.apache.org/confluence/display/' + @ppmc.podlingStatus.wiki,href: 'https://cwiki.apache.org/confluence/display/' + @ppmc.podlingStatus.wiki
      end if @ppmc.podlingStatus.wiki
    end

    _h3 'Licensing'
    _ul do
      _li do
        _a 'IP Clearance Form: '+ @ppmc.podlingStatus.ipClearance, href: @ppmc.podlingStatus.ipClearance
      end if @ppmc.podlingStatus.ipClearance
      _li 'Software Grant Received on: '+@ppmc.podlingStatus.sga if @ppmc.podlingStatus.sga
      _li.podlingWarning 'No Software Grant and No IP Clearance Filed' unless @ppmc.podlingStatus.sga || @ppmc.podlingStatus.ipClearance
      _li 'Confirmation of ASF Copyright Headers on Source Code on: '+@ppmc.podlingStatus.asfCopyright if @ppmc.podlingStatus.asfCopyright
      _li.podlingWarning 'No Release Yet/Missing ASF Copyright Headers on Source Code' unless @ppmc.podlingStatus.asfCopyright
      _li 'Confirmation of Binary Distribution Licensing: '+@ppmc.podlingStatus.distributionRights if @ppmc.podlingStatus.distributionRights
      _li.podlingWarning 'No Release Yet/Binary has licensing issues' unless @ppmc.podlingStatus.distributionRights
    end

    # reporting schedule
    _h3.reporting! 'Reporting Schedule'
    _ul do
      _li @ppmc.schedule.join(', ')
      _li "Monthly: #{@ppmc.monthly.join(', ')}" if @ppmc.monthly and !@ppmc.monthly.empty?
    end

    # website and naming
    _h3 'Naming'
    _ul do
      _li do
        _a "Podling name search (#{@ppmc.namesearch.resolution})", href: 'https://issues.apache.org/jira/browse/' + @ppmc.namesearch.issue
      end if @ppmc.namesearch
      _li.podlingWarning do
        _a "No Podling Name Search on file", href: 'https://incubator.apache.org/guides/names.html#name-search'
      end unless @ppmc.namesearch
      _li do
        _a @ppmc.display_name + ' Website', href: @ppmc.podlingStatus.website
      end
    end
    _h3 'News' unless @ppmc.podlingStatus.news.empty?
    _ul do
      @ppmc.podlingStatus.news.each { |ni|
        _li ni.date + ' - ' + ni.note
      }
    end unless @ppmc.podlingStatus.news.empty?

    # Graduation resolution
    _PPMCGraduate ppmc: @ppmc, id: @@auth.id

    # hidden form
    if @@auth.ppmc or @@auth.ipmc
      _Confirm action: :ppmc, project: @ppmc.id, update: self.update
    end
  end

  # capture ppmc on initial load
  def componentWillMount()
    self.update(@@ppmc)
  end

  # capture ppmc on subsequent loads
  def componentWillReceiveProps()
    self.update(@@ppmc)
  end

  # update ppmc from conformation form
  def update(ppmc)
    @ppmc = ppmc
  end

  # create project in ldap
  def post()
    # construct arguments to fetch
    args = {
      method: 'post',
      credentials: 'include',
      headers: {'Content-Type' => 'application/json'},
      body: {
        project: @ppmc.id, 
        ids: @ppmc.mentors.join(','), 
        action: 'add', 
        targets: ['ldap', 'ppmc', 'committer']
      }.inspect
    }

    @disabled = true
    Polyfill.require(%w(Promise fetch)) do
      @create_disabled = true
      fetch("actions/ppmc", args).then {|response|
        content_type = response.headers.get('content-type') || ''
        if response.status == 200 and content_type.include? 'json'
          response.json().then do |json|
            self.update(json)
          end
        else
          alert "#{response.status} #{response.statusText}"
        end
        @create_disabled = false
      }.catch {|error|
        alert error
        @create_disabled = false
      }
    end
  end
end
