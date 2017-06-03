#
# Show a PPMC
#

class PPMC < React
  def initialize
    @create_disabled = false
  end

  def render
    auth = @@auth and (@@auth.secretary or @@auth.root or
      @ppmc.owners.include? @@auth.id)

    # header
    _h1 do
      _a @ppmc.display_name, 
        href: "https://incubator.apache.org/projects/#{@ppmc.id}.html"
      _small " established #{@ppmc.established}" if @ppmc.established
    end

    _p @ppmc.description

    # usage information for authenticated users (PMC chair, etc.)
    if auth
      _div.alert.alert_success do
        _span 'Double click on a row to show actions.'
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
    _PPMCMentors auth: @@auth.ipmc, ppmc: @ppmc
    _PPMCMembers auth: auth, ppmc: @ppmc
    _PPMCCommitters auth: auth, ppmc: @ppmc

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

      _li do
        _a 'Prior reports', href: 'https://whimsy.apache.org/board/minutes/' +
          @ppmc.display_name.gsub(/\s+/, '_')
      end
    end

    # hidden form
    _Confirm action: :ppmc, project: @ppmc.id, update: self.update if auth
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
