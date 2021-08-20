class ICLA < Vue
  def initialize
    @filed = false
    @checked = nil
    @submitted = false
    @pdfdata = nil # not yet parsed file
    @pdfdisabled = false # true if parse fails
    @pdfbusy = false # busy parsing
  end

  def render
    _h4 'ICLA'

    _div.buttons do
      _button 'clear form', disabled: @filed,
        onClick: lambda {clear_form()}
      _button 'Use mail data', disabled: @filed,
        onClick: lambda {process_response({})}
      _button (@pdfdata.nil? ? 'Parse/use PDF data' : @pdfdisabled ? 'No PDF data found' : 'Use PDF data'),
        disabled: (@filed or @pdfdisabled or @pdfbusy),
        onClick: lambda {getpdfdata()}
    end

    _form method: 'post', action: '../../tasklist/icla', target: 'content' do
      _input type: 'hidden', name: 'message'
      _input type: 'hidden', name: 'selected'
      _input type: 'hidden', name: 'signature', value: @@signature

      _table.form do
        _tr do
          _th 'Submitter'
          _td do
            _ @@headers.name
            _ ' ('
            _ @@headers.from
            _ ')'
          end
        end
        _tr do
          _th 'Real Name'
          _td do
            _input name: 'realname', value: @realname, required: true,
               disabled: (@filed or @pdfbusy),
               onChange: self.changeRealName, onBlur: self.changeRealName
          end
        end

        _tr do
          _th 'Public Name'
          _td do
            _input name: 'pubname', value: @pubname, required: true,
              disabled: (@filed or @pdfbusy), onFocus: lambda {@pubname ||= @realname},
              onChange: self.changePublicName, onBlur: self.changePublicName
          end
        end

        _tr do
          _th 'Family First'
          _td do
            _input name: 'familyfirst', required: true,
              type: 'checkbox', checked: @familyfirst,
              disabled: (@filed or @pdfbusy),
              onChange: self.changeFamilyFirst, onBlur: self.changeFamilyFirst
          end
        end

        _tr do
          _th 'E-mail'
          _td do
            _input name: 'email', value: @email, required: true, type: 'email',
              disabled: (@filed or @pdfbusy)
          end
        end

        _tr do
          _th 'File Name'
          _td do
            _input name: 'filename', value: @filename, required: true,
              pattern: '[a-zA-Z][-\w]+(\.[a-z]+)?', disabled: (@filed or @pdfbusy)
          end
        end
      end

      _table.form do
        _tr do
          _th 'User ID'
          _td do
            _input name: 'user', value: @user, onBlur: self.validate_userid,
              disabled: (@filed or @pdfbusy), pattern: '^[a-z][a-z0-9]{2,}$'
          end
        end

# May be useful in future
#       _tr do
#         _th 'LDAP givenname'
#         _td do
#           _input name: 'ldapgivenname', value: @ldapgivenname,
#             disabled: (@filed or @pdfbusy)
#         end
#       end

#       _tr do
#         _th 'LDAP sn'
#         _td do
#           _input name: 'ldapsn', value: @ldapsn,
#             disabled: (@filed or @pdfbusy)
#         end
#       end
#
        _tr do
          if @project
            _th do
              _a 'Project', href: "https://lists.apache.org/list.html?private@#{@project}.apache.org", target: 'content'
            end
          else
            _th 'Project'
          end
          _td do
            _select name: 'project', value: @project, disabled: (@filed or @pdfbusy) do
              _option ''
              @@projects.each do |project|
                _option project
              end
            end
          end
        end

        unless @pdfproject.nil? or @pdfproject == @project
          _tr do
            _th 'Project (PDF)'
            _td do
              _ @pdfproject
            end
          end
        end

        _tr do
          _th 'Vote Link'
          _td do
            _input type: 'url', name: 'votelink', value: @votelink,
              disabled: @filed
          end
        end
      end

      _input.btn.btn_primary value: 'File', type: 'submit', ref: 'file',
        formnovalidate: true
    end
  end

  # needs to be called even if post fails
  def process_response(parsed)
    name = parsed.FullName || @@headers.name || ''

    # reorder name if there is a single comma present
    parts = name.split(',')
    if parts.length == 2 and parts[1] !~ /^\s*(jr|ph\.d)\.?$/i
      name = "#{parts[1].strip()} #{parts[0]}"
    end

    @realname = name
    @pubname = parsed.PublicName || name
    @familyfirst = parsed.FamilyFirst || false
    @filename = self.genfilename(name, @familyfirst)
    @email = parsed.EMail || @@headers.from
    @user = parsed.ApacheID || ''
    project = parsed.Project
    @project = project if @@projects.include? project
    @pdfproject = parsed.PDFProject
    # Not needed currently
    # pubnamearray = @pubname.split(" ")
    # @ldapsn = self.genldapsn(pubnamearray, @familyfirst)
    # @ldapgivenname = self.genldapgivenname(pubnamearray, @familyfirst)
  end

  # TODO: should this be called by process_response() ?
  def clear_form()
    @pubname = @realname = @email = @filename = @user = ''
    @project = @pdfproject = ''
    @votelink = ''
    @familyfirst = false
  end

  def getpdfdata()
    if @pdfdata # use existing data if present
      process_response(@pdfdata)
    else
      data = {message: window.parent.location.pathname, attachment: @@selected}
      @pdfbusy = true
      HTTP.post('../../actions/parse-icla', data).then {|result|
            @pdfbusy = false
            @pdfdata = result.parsed
            @pdfdisabled = @pdfdata.keys().length <= 1 # response contains dataSource key
            process_response(@pdfdata)
          }.catch {|message|
            @pdfbusy = false
            alert message
          }
    end
  end

  # on initial display, default various fields based on headers, and update
  # state
  def mounted()
    @pdfdata = nil # Not yet parsed
    process_response({}) # preset with message data
    # watch for status updates
    window.addEventListener 'message', self.status_update
  end

  def beforeDestroy()
    window.removeEventListener 'message', self.status_update
  end

  # as fields change, enable/disable the associated buttons and adjust
  # input requirements.
  def updated()
    # ICLA file form
    valid = %w(realname pubname email filename).all? do |name|
      document.querySelector("input[name=#{name}]").validity.valid
    end

    # new account request form - perform checks only if user is valid
    user = document.querySelector("input[name=user]")
    project = document.querySelector("select[name=project]")
    votelink = document.querySelector("input[name=votelink]")

    valid &&= project.validity.valid

    # project votelink are only required with valid users; only validate
    # votelink if the user is valid
    if user.validity.valid and user.value.length > 0
      project.required = votelink.required = true
      valid &= votelink.validity.valid
    else
      votelink.required = false
      project.required = (user.value.length > 0)
    end

    $refs.file.disabled = !valid or @filed or @submitted

    # wire up form
    jQuery('form')[0].addEventListener('submit', self.file)
    jQuery('input[name=message]').val(window.parent.location.pathname)
    jQuery('input[name=selected]').val(decodeURIComponent(@@selected))

    # Safari autocomplete workaround: trigger change on leaving field
    # https://github.com/facebook/react/issues/2125
    if navigator.userAgent.include? "Safari"
      Array(document.getElementsByTagName('input')).each do |input|
        input.addEventListener('blur', self.onblur)
      end
    end
  end

  # when real name changes, update file name
  def changeRealName(event)
    @realname = event.target.value;
    @filename = self.genfilename(@realname, @familyfirst)
  end

  # when family first changes, update file name and LDAP default fields
  def changeFamilyFirst(event)
    @filename = self.genfilename(@realname, @familyfirst)
    # not needed currently
    # pubnamearray = @pubname.split(' ')
    # @ldapsn = self.genldapsn(pubnamearray, @familyfirst)
    # @ldapgivenname = self.genldapgivenname(pubnamearray, @familyfirst)
  end

  # when public name changes, update LDAP default fields
  def changePublicName(event)
    @pubname = event.target.value;
    # not needed currently
    # pubnamearray = @pubname.split(' ')
    # @ldapsn = self.genldapsn(pubnamearray, @familyfirst)
    # @ldapgivenname = self.genldapgivenname(pubnamearray, @familyfirst)
  end

  # generate file name from the real name
  def genfilename(realname, familyfirst)
    nominalname = asciize(realname.strip()).downcase().gsub(/\W+/, '-')
    if !familyfirst
      return nominalname
    else
      # compute file name with family first; move first name to last
      namearray = nominalname.split("-")
      namearray.push(namearray[0])
      namearray.shift()
      return namearray.join("-")
    end
  end

  # generate LDAP sn from public name
  # simply return either the first or last name
  def genldapsn(pnamearray, ffirst)
    if ffirst
      return pnamearray[0]
    else
      return pnamearray[-1]
    end
  end

  # generate LDAP givenName from public name
  # simply return the remainder after removing either the first or last name
  def genldapgivenname(pnamearray, ffirst)
    if ffirst
      pnamearray.shift()
      return pnamearray.join(' ')
    else
      pnamearray.pop()
      return pnamearray.join(' ')
    end
  end

  # when leaving an input field, trigger change event (for Safari)
  def onblur(event)
    jQuery(event.target).trigger(:change)
  end

  # handle ICLA form submission
  def file(event)
    setTimeout 0 do
      @submitted = true
      @filed = true
    end
  end

  # validate userid is available
  def validate_userid(event)
    return unless @user and @user != @checked
    input = event.target
    HTTP.post('../../actions/check-id', id: @user).then {|result|
      input.setCustomValidity(result.message)
      @checked = @user
    }.catch {|message|
      alert message
    }
  end

  # when tasks complete (or are aborted) reset form
  def status_update(event)
    @submitted = false
    @filed = false
  end
end
