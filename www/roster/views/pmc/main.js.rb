#
# Show a PMC
#

class PMC < Vue
  def initialize
    @attic = nil
  end

  def render
    auth = (@@auth.secretary or @@auth.root or
      @committee.members.include? @@auth.id)

    # add jump links to main sections of page using Bootstrap nav element
    _ul.nav.nav_pills do
      _li role: "presentation" do
        _a 'PMC', :href => "committee/#{@committee.id}#pmc"
      end
      _li role: "presentation" do
        _a 'Committers', :href => "committee/#{@committee.id}#committers"
      end
      _li role: "presentation" do
        if @committee.moderators
          _a 'Mail List Info', :href => "committee/#{@committee.id}#mail"
        else
          _a 'Mail Lists', :href => "committee/#{@committee.id}#mail"
        end
      end
      _li role: "presentation" do
        _a 'Reporting Schedule', :href => "committee/#{@committee.id}#reporting"
      end
      _li role: "presentation" do
        _a 'Links', :href => "committee/#{@committee.id}#links"
      end
    end

    # header
    _h1 do
      _a @committee.display_name, href: @committee.site
      _small " established #{@committee.established}" if @committee.established
      if @committee.image
        _img src: "https://apache.org/logos/res/#{@committee.id}/default.png"
      end
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

    # action bar: add, modify, search
    _div.row key: 'databar' do
      _div.col_sm_6 do
        if auth
          _button.btn.btn_default 'Add',
            data_target: '#pmcadd', data_toggle: 'modal'

          mod_disabled = true
          for id in @committee.roster
            if @committee.roster[id].selected
              mod_disabled = false
              break
            end
          end

          if mod_disabled
            _button.btn.btn_default 'Modify', disabled: true
          else
            _button.btn.btn_primary 'Modify',
              data_target: '#pmcmod', data_toggle: 'modal'
          end
          _p do
            _br
            _ 'Note: to Add existing committers to the PMC, please select the committer from the list below and use the Modify button instead.'
            _br
            _ 'N.B. please ask the committer to subscribe themselves to the private list, for example by using the'
            _br
            _ 'Mailing List Subscription Helper '
            _a 'https://whimsy.apache.org/committers/subscribe', href: 'https://whimsy.apache.org/committers/subscribe'
          end
        end
      end
      _div.col_sm_6 do
        _input.form_control type: 'search', placeholder: 'search',
          value: @search
      end
    end

    # main content
    if @search
      _ProjectSearch auth: auth, project: @committee, search: @search
    else
      _PMCMembers auth: auth, committee: @committee
      _PMCCommitters auth: auth, committee: @committee
    end

    # mailing lists
    if @committee.moderators
      _h2.mail! do
        _ 'Mailing list info'
        _small ' (subscriber count excludes known archivers)'
      end
      _table.table do
        _thead do
          _tr do
            _th 'list name'
            _th do
              _ 'moderators'
              _small " (last checked #{@committee.modtime})"
            end
            _th do
              _ 'subscribers'
              _small " (last checked #{@committee.subtime})"
            end
          end
        end
        _tbody do
          for list_name in @committee.moderators
            _tr do
              _td do
                _a list_name, href: 'https://lists.apache.org/list.html?' +
                  list_name
              end
              _td do
                sep=''
                @committee.moderators[list_name].each { |mod|
                  _ sep
                  id=nil
                  if mod.end_with? '@apache.org'
                    id=mod.sub(/@a.*/,'')
                  else
                    id = @committee.nonASFmails[mod]
                  end
                  if id
                    _a mod, href: "committer/#{id}"
                  else
                    _ mod
                  end
                  sep=', '
                }
              end
              _td @committee.subscribers[list_name]
            end
          end
        end
      end
    else
      _h2.mail! 'Mail lists'
      _ul do
        for list_name in @committee.mail
          _li do
            _a list_name, href: 'https://lists.apache.org/list.html?' +
              list_name
          end
        end
      end
    end

    _br
    _p do
      _b 'List moderators can obtain subscriber names etc by following '
      _a 'these instructions', href: 'https://infra.apache.org/mailing-list-moderation.html'
    end

    # reporting schedule and links
    _div.row do
      _div.col_md_6 do
        _h3.reporting! 'Reporting Schedule'
        _ul do
          _li @committee.report
          if @committee.schedule and @committee.schedule != @committee.report
            _li @committee.schedule
          end
          _li do
            _a 'Prior reports', href: 'https://whimsy.apache.org/board/minutes/' +
              @committee.display_name.gsub(/\s+/, '_')
          end
          if @committee.members.include?(@@auth.id) or @@auth.member
            _li do
              _a 'Apache Committee Report Helper',
                href: "https://reporter.apache.org/?#{@committee.id}"
            end
          end
        end
      end
      _div.col_md_6 do
        _h3.links! 'Links'
        _ul do
          _li {_a 'Site check', href: "../site/project/#{@committee.id}"}
          info = @committee.project_info
          if info
            if info.doap
              _li {_a 'DOAP', href: info.doap}
            end
            if info['download-page']
              _li {_a 'Download Page', href: info['download-page']}
            end
            if info['bug-database']
              _li {_a 'Bug Database', href: info['bug-database']}
            end
            if info.repository and not info.repository.empty?
              if info.repository.length == 1
                _li {_a 'Repository', href: info.repository.first}
              else
                _li do
                  _span 'Repositories:'
                  _ul info.repository do |repository|
                    _li {_a repository, href: repository}
                  end
                end
              end
            end
          end
        end
      end
    end

    # hidden forms
    if auth
      _Confirm action: :committee, project: @committee.id, update: self.update
      _PMCAdd project: @@committee, onUpdate: self.update
      _PMCMod project: @@committee, onUpdate: self.update
    end
  end

  # capture committee on initial load
  def created()
    self.update(@@committee)
  end

  # update committee from conformation form
  def update(committee)
    @committee = committee

    @committee.refresh = proc { Vue.forceUpdate() }

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
          console.log "Attic JIRA #{error}"
        }
      end
    end
  end
end
