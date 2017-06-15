class Person < React
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
    _PersonName person: self

    # Personal URL
    if @committer.urls
      _PersonUrls person: self
    end

    # Committees
    committees = @committer.committees
    unless committees.empty?
      _div.row do
        	_div.name 'Committees'
        	_div.value do
        	  _ul committees do |pmc|
        	    _li {_a pmc, href: "committee/#{pmc}"}
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

    # Email addresses
    if @committer.mail
      _PersonEmail person: self
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
        	end
      end
    end

    # PGP keys
    if @committer.pgp
      _PersonPgpKeys person: self
    end

    # SSH keys
    if @committer.ssh
      _PersonSshKeys person: self
    end

    # GitHub username
    if @committer.githubUsername
      _PersonGitHub person: self
    end

    if @committer.member
      _PersonMemberStatus person: self

      # Members.txt
      if @committer.member.info
        _PersonMemberText person: self
      end

      if @committer.member.nomination
        	_div.row do
        	  _div.name 'Nomination'
        	  _div.value {_pre @committer.member.nomination}
        	end
      end

      # Forms on file
      if @committer.forms
        _PersonForms person: self
      end
    end

    # SpamAssassin score
    _PersonSascore person: self

    # modal dialog for dry run results
    _div.modal.fade.wide_form tabindex: -1 do
      _div.modal_dialog do
        _div.modal_content do
          _div.modal_header do
            _button.close 'x', data_dismiss: 'modal'
            _h4 'Dry run results'
          end
          _div.modal_body do
            _textarea value: JSON.stringify(@response, nil, 2), readonly: true
          end
          _div.modal_footer do
            _button.btn.btn_default 'Close', data_dismiss: 'modal'
          end
        end
      end
    end
  end

  # capture committer on initial load
  def componentWillMount()
    self.componentWillReceiveProps()
  end

  # replace committer on change, determine if user is authorized to make
  # changes
  def componentWillReceiveProps()
    if @committer.id != @@committer.id
      @committer = @@committer
      @auth = (@@auth.id == @@committer.id or @@auth.secretary or @@auth.root)
    end
  end

  # on initial display, look for add editable rows, highlight them,
  # and watch for double clicks on them
  def componentDidMount()
    return unless @auth
    Array(document.querySelectorAll('div.row[data-edit]')).each do |div|
      div.addEventListener('dblclick', self.dblclick)
      div.querySelector('div.name').classList.add 'bg-success'
    end
  end

  # when a double click occurs, toggle the associated state
  def dblclick(event)
    tr = event.currentTarget
    field = "edit_#{tr.dataset.edit}"
    changes = {}
    changes[field] = !self.state[field]
    self.setState changes
    window.getSelection().removeAllRanges()
  end

  # after update, register event listeners on forms
  def componentDidUpdate()
    Array(document.querySelectorAll('tr[data-edit]')).each do |tr|
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
        tr = form.closest('tr')[0]
        if tr
          field = "edit_#{tr.dataset.edit}"
          changes = {}
          changes[field] = false
          self.setState changes
        end
      },

      error: ->(response) {
        alert response.statusText
      },

      complete: ->(response) do
        # show results of dryrun
        if formData[0] and formData[0].name == 'dryrun'
          @response = response.responseJSON
          jQuery('div.modal').modal('show')
        end

        # reenable form for later reuse
        jQuery('input, button', form).prop('disabled', false)
      end
    )

    # disable input
    jQuery('input, button', form).prop('disabled', true)
  end
end
