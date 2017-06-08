#
# Show a PPMC
#

class PPMC < React
  def initialize
    @create_disabled = false
  end

  def render
    if @@auth
      @@auth.ppmc = (@@auth.secretary or @@auth.root or
        @ppmc.owners.include? @@auth.id)
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
      _h2.mail! 'Mail list moderators'
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
      _h2.mail! 'Mail lists'
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

    # reporting schedule
    _h2.reporting! 'Reporting Schedule'
    _ul do
      _li @ppmc.schedule.join(', ')
      _li "Monthly: #{@ppmc.monthly.join (', ')}" if @ppmc.monthly and !@ppmc.monthly.empty?
      _li do
        _a 'Prior Board Reports', href: 'https://whimsy.apache.org/board/minutes/' +
          @ppmc.display_name.gsub(/\s+/, '_')
      end
    end

    _h2.podlingStatus! 'Podling Status'
    _h3 'Naming'
    _ul do
      _li do
        _a "Podling name search (#{@ppmc.namesearch.resolution})", href: 'https://issues.apache.org/jira/browse/' + @ppmc.namesearch.issue
      end if @ppmc.namesearch
      _li do
        _a "No Podling Name Search on file", href: 'https://incubator.apache.org/guides/names.html#name-search'
      end if !@ppmc.namesearch
    end

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
        alert errror
        @create_disabled = false
      }
    end
  end
end
