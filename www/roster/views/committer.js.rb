class Committer < React
  def initialize
    @committer = {}
  end

  def render
    # usage information for authenticated users (owner, secretary, etc.)
    if @auth
      _div.alert.alert_success 'Double click on a field in this color to edit.'
    end

    _h2 "#{@committer.id}@apache.org"

    _table.wide do

      _tr do
        _td 'Name'
        _td do
          name = @committer.name

          if name.public_name==name.legal_name and name.public_name==name.ldap
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
        if @committer.member.status
          _tr do
            _td 'Member status'
            if @committer.member.info
              _td @committer.member.status
            else
              _td.not_found 'Not in members.txt'
            end
          end
        end

        if @committer.member.info
          _tr do
            _td 'Members.txt'
            _td do
              _pre @committer.member.info,
                class: ('small' if @committer.member.info =~ /.{81}/)
            end
          end
        end

        if @committer.member.nomination
          _tr do
            _td 'Nomination'
            _td {_pre @committer.member.nomination}
          end
        end
        j
        if @committer.forms
          _tr do
            _td 'Forms on file'
            _td do
              _ul do
                for form in @committer.forms
                  link = @committer.forms[form]
                  
                  if form == 'icla'
                    _li do
                      _a 'ICLA', href: "https://svn.apache.org/repos/private/documents/iclas/#{link}"
                    end
                  elsif form == 'member'
                    _li do
                      _a 'Membership App', href: "https://svn.apache.org/repos/private/documents/member_apps/#{link}"
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
      form.addEventListener 'submit', self.submit if form
    end
  end

  # submit form using AJAX
  def submit(event)
    event.preventDefault()
    form = event.currentTarget
    target = form.target

    jQuery.ajax(
      method: (form.method || 'GET').upcase(),
      data: jQuery(form).serialize(),
      dataType: 'json',

      success: ->(response) {
        @committer = response

        # turn off edit mode on this field
        tr = jQuery(document.querySelector('form')).closest('tr')[0]
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
        # reenable form for later reuse
        Array(form.querySelectorAll('input')).each do |input|
          input.disabled = false
        end
      end
    )

    Array(form.querySelectorAll('input')).each do |input|
      input.disabled = true
    end
  end
end
