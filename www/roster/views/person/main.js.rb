class Person < Vue
  def initialize
    @committer = {}
    @response = nil
  end

  def render
    # usage information for authenticated users (owner, secretary, etc.)
    if @auth
      _div.alert.alert_success 'Double click on a field in this color to edit.'
    end

    _h2 "#{@committer.id}@apache.org"

    # Name
    _PersonName person: self, edit: @edit

    _div.row do
      _div.name 'LDAP Create Date'
      _div.value do
        _ @committer.createTimestamp
      end
    end

    # Personal URL
    if @committer.urls || @auth
      @committer.urls ||= []
      _PersonUrls person: self, edit: @edit
    end

    # PMCs
    noPMCsub = false
    pmcs = @committer.pmcs
    unless pmcs.empty?
      _div.row do
        _div.name 'PMCs'
        _div.value do
          _ul pmcs do |pmc|
            _li {
              _a pmc, href: "committee/#{pmc}"
              if @committer.privateNosub
                if @committer.privateNosub.include? pmc
                  noPMCsub = true
                  _b " (*)"
                end
              end
              if @committer.chairOf.include? pmc
                _ ' (chair)'
              end
              unless @committer.committees.include?(pmc)
                _b ' (not in LDAP committee group)'
              end
            }
          end
          if noPMCsub
                  _br
            _p {
              _ '(*) could not find a subscription to the private@ mailing list for this PMC'
              _br
              _ 'Perhaps the subscription address is not listed in the LDAP record'
              _br
              _ '(Note that digest subscriptions are not currently included)'
            }
          end
        end
      end
    end

    # Committees
    missingPMCs = false
    committees = @committer.committees
    unless committees.empty?
      _div.row do
        _div.name 'Committees'
        _div.value do
          noPMCsub = false
          _ul committees do |pmc|
            next if  @committer.pmcs.include? pmc
            missingPMCs = true
            _li {
              _a pmc, href: "committee/#{pmc}"
              if @committer.chairOf.include? pmc
                _ ' (chair)'
              end
            }
          end
          if missingPMCs
            _ 'In LDAP committee group, but not on the corresponding PMC'
          else
            _ '(excludes PMCs listed above)'
          end
        end
      end
    end

    # Committer
    commit_list = @committer.committer
    unless commit_list.all? {|pmc| committees.include? pmc}
      _div.row do
        _div.name 'Committer'
        _div.value do
          _ul commit_list do |pmc|
            next if committees.include? pmc
            _li {_a pmc, href: "committee/#{pmc}"}
          end
        end
      end
    end

    # Groups
    unless @committer.groups.empty?
      _div.row do
        _div.name 'Groups'
        _div.value do
          _ul @committer.groups do |group|
            next if group == 'apldap'

            if group == 'committers'
              _li {_a group, href: "committer/"}
            elsif group == 'member'
              _li {_a group, href: "members"}
            else
              _li {_a group, href: "group/#{group}"}
            end
            if @committer.chairOf.length > 0 and not @committer.groups.include? 'pmc-chairs'
              _ '[Missing: pmc-chairs]'
            end
          end
        end
      end
    end

    # Podlings
    unless @committer.podlings.empty?
      _div.row do
        _div.name 'Podlings'
        _div.value do
          _ul @committer.podlings do |podlings|
            _li {_a podlings, href: "ppmc/#{podlings}"}
          end
        end
      end
    end

    # Non-PMCs
    nonpmcs = @committer.nonpmcs
    unless nonpmcs.empty?
      _div.row do
        _div.name 'non-PMCs'
        _div.value do
          _ul nonpmcs do |nonpmc|
            _li {
              _a nonpmc, href: "nonpmc/#{nonpmc}"
              if @committer.nonPMCchairOf.include? nonpmc
                _ ' (chair)'
              end
            }
          end
        end
      end
    end

    if @auth # deprecate using outlook.com
      _div.row do
        _div.name 'Email provider issues'
        _div.value do
          _ 'Some providers are known to block our emails as SPAM.'
          _br
          _ 'Please see the following for details: '
          _a 'email provider issues', href: '../committers/emailissues', target: '_blank'
          _ ' (opens in new page)'
        end
      end
    end

    # Email addresses
    # always present
    _PersonEmailForwards person: self, edit: @edit

    # always present (even if an empty array)
    _PersonEmailAlt person: self, edit: @edit

    if @committer.email_other
      _PersonEmailOther person: self # not editable
    end

    # Moderates
    if @committer.moderates and @committer.moderates.keys().length > 0
      _div.row do
        _div.name 'Moderates'
        _div.value do
          _ul @committer.moderates.keys() do |list_name|
            _li do
              _a list_name, href: 'https://lists.apache.org/list.html?' +
                list_name
              _span " as "
              _span @committer.moderates[list_name].join(', ')
            end
          end
          _ "(last checked #{@committer.modtime})"
        end
      end
    end

    # subscriptions
    if @committer.subscriptions
      _div.row do
        _div.name 'Subscriptions'
        _div.value do
          _ul @committer.subscriptions do |list_email|
            _li do
              _a list_email[0],
                href: 'https://lists.apache.org/list.html?' + list_email[0]
              _span " as "
              _span list_email[1]
            end
          end
          _ "(last checked #{@committer.subtime})"
        end
      end
    end

    # digests
    if @committer.digests
      _div.row do
        _div.name 'Digest Subscriptions'
        _div.value do
          _ul @committer.digests do |list_email|
            _li do
              _a list_email[0],
                href: 'https://lists.apache.org/list.html?' + list_email[0]
              _span " as "
              _span list_email[1]
            end
          end
          _ "(last checked #{@committer.digtime})"
        end
      end
    end

    # PGP keys
    if @committer.pgp || @auth
      @committer.pgp ||= []
      _PersonPgpKeys person: self, edit: @edit
    end

    # hosts
    _div.row do
      _div.name 'Host Access'
      _div.value do
        # pre avoids wrapping on hyphens and reduces number of lines on the page
        _pre @committer.host.join(' ')
      end
    end

    if @committer.inactive
      _div.row do
        _div.name 'Inactive (cannot login)'
        _div.value @committer.inactive
      end
    end

    # SSH keys
    if @committer.ssh || @auth
      @committer.ssh ||= []
      _PersonSshKeys person: self, edit: @edit
    end

    # GitHub username
    if @committer.githubUsername || @auth
      @committer.githubUsername ||= []
      _PersonGitHub person: self, edit: @edit
    end

    if @committer.member
      _PersonMemberStatus person: self, edit: @edit

      # Members.txt
      if @committer.member.info
        _PersonMemberText person: self, edit: @edit
      end

      if @committer.member.nomination
        _div.row do
          _div.name 'Nomination'
          _div.value {_pre @committer.member.nomination}
        end
      end

    end

    # Forms on file (only present if env.user is a member)
    if @committer.forms
      _PersonForms person: self
    end

    # SpamAssassin score
    _PersonSascore person: self, edit: @edit

    # modal dialog for dry run results and errors
    _div.modal.fade.wide_form tabindex: -1 do
      _div.modal_dialog do
        _div.modal_content do
          _div.modal_header do
            _button.close 'x', data_dismiss: 'modal'
            _h4 @response_title
          end
          _div.modal_body do
            _textarea value: @response, readonly: true
          end
          _div.modal_footer do
            _button.btn.btn_default 'Close', data_dismiss: 'modal'
          end
        end
      end
    end
  end

  # initialize committer, determine if user is authorized to make
  # changes, map Vue model to React model
  def created()
    @committer = @@committer
    @auth = (@@auth.id == @@committer.id or @@auth.secretary or @@auth.root)

    # map Vue model to React model
    self.state = self['$data']
    self.props = self['$props']
  end

  # on initial display, look for add editable rows, highlight them,
  # and watch for double clicks on them
  def mounted()
    return unless @auth

    Array(document.querySelectorAll('div.row[data-edit]')).each do |div|
      div.addEventListener('dblclick', self.dblclick)
      div.querySelector('div.name').classList.add 'bg-success'
    end
  end

  # when a double click occurs, toggle the associated state
  def dblclick(event)
    row = event.currentTarget

    if row.dataset.edit == @edit
      @edit = nil
    else
      @edit = row.dataset.edit
    end

    window.getSelection().removeAllRanges()
  end

  # after update, register event listeners on forms
  def updated()
    Array(document.querySelectorAll('div[data-edit]')).each do |tr|
      form = tr.querySelector('form')
      if form
        form.setAttribute 'data-action', tr.getAttribute('data-edit')
        jQuery('input[type=submit],button', form).click(self.submit)
      end
    end
  end

  # submit form using AJAX
  def submit(event)
    event.preventDefault()
    form = jQuery(event.currentTarget).closest('form')
    target = event.target

    # if (cancel) button is pressed, don't submit but remove @edit form
    cancel_submit = target.getAttribute('data-cancel-submit')

    if cancel_submit
      # remove the edit buttons and return
      @edit = nil
      return
    end

    # serialize form
    formData = form.serializeArray();

    # add button if it has a value
    if target and target.getAttribute('name') and target.getAttribute('value')
      formData.push name: target.getAttribute('name'),
        value: target.getAttribute('value')
    end

    # indicate dryrun is requested if option or control key is down
    if event.altKey or event.ctrlKey
      formData.unshift name: 'dryrun', value: true
    end

    # issue request
    jQuery.ajax(
      method: (form[0].method || 'GET').upcase(),
      url: document.location.href + '/' + form[0].getAttribute('data-action'),
      data: formData,
      dataType: 'json',

      success: ->(response) {
        @committer = response.committer if response.committer

        # turn off edit mode on this field
        row = form.closest('.row')[0]
        @edit = nil if row and row.dataset.edit == @edit
      },

      error: ->(response) {
        json = response.responseJSON
        if json.exception
          @response_title = json.exception
          @response = JSON.stringify(json, nil, 2)
          jQuery('div.modal').modal('show')
        else
          alert response.statusText
        end
      },

      complete: ->(response) do
        json = response.responseJSON
        # show results of dryrun
        if formData[0] and formData[0].name == 'dryrun'
          @response_title = 'Dry run results'
          @response = JSON.stringify(json, nil, 2)
          jQuery('div.modal').modal('show')
        end

        if json.error
          @response_title = 'Error occurred'
          @response = JSON.stringify(json, nil, 2)
          jQuery('div.modal').modal('show')
        elsif json.warn
          alert json.warn
        end

        # re-enable form for later reuse
        jQuery('input, button', form).prop('disabled', false)
      end
    )

    # disable input
    jQuery('input, button', form).prop('disabled', true)
  end
end
