class Committer < React
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

    _table.wide do

      # Name
      _tr data_edit: ('pubname' if @@auth.secretary) do
        _td 'Name'
        _td do
          name = @committer.name

          if @edit_pubname
            _form.inline method: 'post' do
              _div do
                _label 'public name', for: 'publicname'
                _input.publicname! name: 'publicname', required: true,
                  defaultValue: name.public_name
              end
              _div do
                _label 'legal name', for: 'legalname'
                _input.legalname! name: 'legalname', required: true,
                  defaultValue: name.legal_name
              end
              _button.btn.btn_primary 'submit'
            end
          else
            if 
              name.public_name==name.legal_name and 
              name.public_name==name.ldap
            then
              _span @committer.name.public_name
            else
              _ul do
                _li "#{@committer.name.public_name} (public name)"
  
                if name.legal_name and name.legal_name != name.public_name
                  _li "#{@committer.name.legal_name} (legal name)"
                end
  
                if name.ldap and name.ldap != name.public_name
                  _li "#{@committer.name.ldap} (ldap)"
                end
              end
            end
          end
        end
      end

      # Personal URL
      if @committer.urls
        _tr do
          _td 'Personal URL'
          _td do
            _ul @committer.urls do |url|
              _li {_a url, href: url}
            end
          end
        end
      end

      # Committees
      committees = @committer.committees
      unless committees.empty?
        _tr do
          _td 'Committees'
          _td do
            _ul committees do |pmc|
              _li {_a pmc, href: "committee/#{pmc}"}
            end
          end
        end
      end

      # Committer
      commit_list = @committer.committer
      unless commit_list.all? {|pmc| committees.include? pmc}
        _tr do
          _td 'Committer'
          _td do
            _ul commit_list do |pmc|
              next if committees.include? pmc
              _li {_a pmc, href: "committee/#{pmc}"}
            end
          end
        end
      end

      # Groups
      unless @committer.groups.empty?
        _tr do
          _td 'Groups'
          _td do
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

      # Email addresses
      if @committer.mail
        _tr do
          _td 'Email addresses'
          _td do
            _ul @committer.mail do |url|
              _li do
                _a url, href: 'mailto:' + url
              end
            end
          end
        end
      end

      # PGP keys
      if @committer.pgp
        _tr do
          _td 'PGP keys'
          _td do
            _ul @committer.pgp do |key|
              _li do
                if key =~ /^[0-9a-fA-F ]+$/
                  _samp do
                    _a key, href: 'https://sks-keyservers.net/pks/lookup?' +
                      'op=index&search=0x' + key.gsub(' ', '')
                  end
                else
                  _samp key
                end
              end
            end
          end
        end
      end

      # SSH keys
      if @committer.ssh
        _tr do
          _td 'SSH keys'
          _td do
            _ul @committer.ssh do |key|
              _li.ssh do
                _pre.wide key
              end
            end
          end
        end
      end

      # GitHub username
      if @committer.githubUsername
        _tr do
          _td 'GitHub username'
          _td do
            _a @committer.githubUsername, href: 
              "https://github.com/" + @committer.githubUsername
          end
        end
      end

      if @committer.member
        # Member status
        if @committer.member.status
          _tr data_edit: ('memstat' if @@auth.secretary) do
            _td 'Member status'
            if @committer.member.info
              _td do
                _span @committer.member.status
               if @edit_memstat
                 _form.inline method: 'post' do
                   if @committer.member.status.include? 'Active'
                     _button.btn.btn_primary 'move to emeritus',
                       name: 'action', value: 'emeritus'
                   elsif @committer.member.status.include? 'Emeritus'
                     _button.btn.btn_primary 'move to active',
                       name: 'action', value: 'active'
                   end
                 end
               end
              end
            else
              _td.not_found 'Not in members.txt'
            end
          end
        end

        # Members.txt
        if @committer.member.info
          _tr data_edit: 'memtext' do
            _td 'Members.txt'
            _td do
              if @edit_memtext
                _form.inline method: 'post' do
                  _div do
                    _textarea defaultValue: @committer.member.info
                  end
                  _button.btn.btn_primary 'submit'
                end
              else
                _pre @committer.member.info,
                  class: ('small' if @committer.member.info =~ /.{81}/)
              end
            end
          end
        end

        if @committer.member.nomination
          _tr do
            _td 'Nomination'
            _td {_pre @committer.member.nomination}
          end
        end

        # Forms on file
        if @committer.forms
          documents = "https://svn.apache.org/repos/private/documents"
          _tr do
            _td 'Forms on file'
            _td do
              _ul do
                for form in @committer.forms
                  link = @committer.forms[form]
                  
                  if form == 'icla'
                    _li do
                      _a 'ICLA', href: "#{documents}/iclas/#{link}"
                    end
                  elsif form == 'member'
                    _li do
                      _a 'Membership App', 
                        href: "#{documents}/member_apps/#{link}"
                    end
                  else
                    _li "#{form}: #{link}"
                  end
                end
              end
            end
          end
        end
      end

      # SpamAssassin score
      _tr data_edit: 'sascore' do
        _td 'SpamAssassin score'
        _td do
          if @edit_sascore
            _form method: 'post' do
              _input type: 'number', min: 0, max: 10, 
                name: 'sascore', defaultValue: @committer.sascore
              _input type: 'submit', value: 'submit'
            end
          else
            _span @committer.sascore
          end
        end
      end
    end

    # modal dialog for dry run results
    _div.modal.fade tabindex: -1 do
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
    Array(document.querySelectorAll('tr[data-edit]')).each do |tr|
      tr.addEventListener('dblclick', self.dblclick)
      tr.querySelector('td').classList.add 'bg-success'
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
