#
# Show a Committee
#

class NonPMC < Vue
  def initialize
    @attic = nil
  end

  def render
    # TODO establish the correct auth for non-PMCs - may not have LDAP
#    auth = (@@auth.secretary or @@auth.root or
#      @nonpmc.members.include? @@auth.id)

    auth = nil # The modules have not been checked

    # add jump links to main sections of page using Bootstrap nav element
    _ul.nav.nav_pills do
      _li role: "presentation" do
        _a 'Committee', :href => "nonpmc/#{@nonpmc.id}#pmc"
      end
      _li role: "presentation" do
        _a 'Committers', :href => "nonpmc/#{@nonpmc.id}#committers"
      end
      _li role: "presentation" do
        if @nonpmc.moderators
          _a 'Mail List Info', :href => "nonpmc/#{@nonpmc.id}#mail"
        else
          _a 'Mail Lists', :href => "nonpmc/#{@nonpmc.id}#mail"
        end
      end
    end
    # header
    _h1 do
      _a @nonpmc.display_name, href: @nonpmc.site
      _small " established #{@nonpmc.established}" if @nonpmc.established
      if @nonpmc.image
        _img src: "https://apache.org/img/#{@nonpmc.image}"
      end
    end

    _p @nonpmc.description

    # action bar: add, modify, search
    _div.row key: 'databar' do
      _div.col_sm_6 do
        if auth
          _button.btn.btn_default 'Add',
            data_target: '#pmcadd', data_toggle: 'modal'

          mod_disabled = true
          for id in @nonpmc.roster
            if @nonpmc.roster[id].selected
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
            _ 'Note: to Add existing committers to the Committee, please select the committer from the list below and use the Modify button instead.'
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
      _ProjectSearch auth: auth, project: @nonpmc, search: @search
    else
      _NonPMCMembers auth: auth, nonpmc: @nonpmc
      _NonPMCCommitters auth: auth, nonpmc: @nonpmc
    end

    # mailing lists
    if @nonpmc.moderators
      _h2.mail! do
        _ 'Mailing list info'
        _small ' (subscriber count includes archivers)'
      end
      _table do
        _thead do
          _tr do
            _th 'list name'
            _th do
              _ 'moderators'
              _small " (last checked #{@nonpmc.modtime})"
            end
            _th do
              _ 'subscribers'
              _small " (last checked #{@nonpmc.subtime})"
            end
          end
        end
        _tbody do
          for list_name in @nonpmc.moderators
            _tr do
              _td do
                _a list_name, href: 'https://lists.apache.org/list.html?' +
                  list_name
              end
              _td do
                sep=''
                @nonpmc.moderators[list_name].each { |mod|
                  _ sep
                  id=nil
                  if mod.end_with? '@apache.org'
                    id=mod.sub(/@a.*/,'')
                  else
                    id = @nonpmc.nonASFmails[mod]
                  end
                  if id
                    _a mod, href: "committer/#{id}"
                  else
                    _ mod
                  end
                  sep=', '
                }
              end
              _td @nonpmc.subscribers[list_name]
            end
          end
        end
      end
    else
      _h2.mail! 'Mail lists'
      _ul do
        for mail_name in @nonpmc.mail
          parsed = mail_name.match(/^(.*?)-(.*)/)
          list_name = "#{parsed[2]}@#{parsed[1]}.apache.org"
          _li do
            _a list_name, href: 'https://lists.apache.org/list.html?' +
              list_name
          end
        end
      end
    end

    # reporting schedule and links
    if @nonpmc.report
      _div.row do
        _div.col_md_6 do
          _h3.reporting! 'Reporting Schedule'
          _ul do
            _li @nonpmc.report
            if @nonpmc.schedule and @nonpmc.schedule != @nonpmc.report
              _li @nonpmc.schedule 
            end
            _li do
              _a 'Prior reports', href: 'https://whimsy.apache.org/board/minutes/' +
                @nonpmc.display_name.gsub(/\s+/, '_')
            end
          end
        end
      end
    end

    # hidden forms
    if auth
      _Confirm action: :nonpmc, project: @nonpmc.id, update: self.update
      _NonPMCAdd project: @@nonpmc, onUpdate: self.update
      _NonPMCMod project: @@nonpmc, onUpdate: self.update
    end
  end

  # capture nonpmc on initial load
  def created()
    self.update(@@nonpmc)
  end

  # update nonpmc from conformation form
  def update(nonpmc)
    @nonpmc = nonpmc

    @nonpmc.refresh = proc { Vue.forceUpdate() }

    if @attic == nil and not nonpmc.established and defined? fetch
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
