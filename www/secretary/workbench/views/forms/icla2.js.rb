class ICLA2 < Vue
  def initialize
    @filed = false
    @checked = nil
    @submitted = false
    @search = ''
    @iclas = []
  end

  def render
    _h4 'Additional ICLA'

    _form.form do
      _h5 'Search'
      _table.form do
        _tr do
          _input value: @search
        end
      end
    end

    if @search.length >= 3 and not @iclas.empty?
      search = @search.downcase().split(' ')
      _ul.icla_search do
        @iclas.each do |icla|
          if
            search.all? {|part|
              icla.id.include? part or
              icla.name.downcase().include? part or
              icla.fullname.downcase().include? part
            }
          then
            _li do
              _input type: 'radio', name: 'icla',
                onClick: lambda {
                  window.parent.frames.content.location.href =
                    location.toString()[/.*\//] + @@selected
                  @icla = icla
                }
              _a icla.name, href: "../../icla/#{icla.filename}",
                target: 'content'
           end
          end
        end
      end
    end

    _form method: 'post', action: '../../tasklist/icla2', target: 'content' do
      _input type: 'hidden', name: 'message'
      _input type: 'hidden', name: 'selected'
      _input type: 'hidden', name: 'signature', value: @@signature
      _input type: 'hidden', name: 'filename', value: @icla && @icla.filename
      _input type: 'hidden', name: 'id', value: @icla && @icla.id
      _input type: 'hidden', name: 'oldemail', value: @icla && @icla.email

      _h5 'Current values'

      _table.form do
        _tr do
          _th 'Full Name'
          _td @icla && @icla.fullname
        end

        _tr do
          _th 'Public Name'
          _td @icla && @icla.name
        end

        _tr do
          _th 'E-mail'
          _td @icla && @icla.email
        end

        _tr do
          _th 'File Name'
          _td @icla && @icla.filename
        end

        _tr do
          _th 'AvailId'
          _td @icla && @icla.id
        end
      end

      _h5 'Updated values'
      _table.form do
        _tr do
          _th 'Public Name'
          _td do
            _input name: 'pubname', value: @pubname, required: true,
              disabled: @filed, onFocus: lambda {@pubname ||= @realname}
          end
        end

        _tr do
          _th 'E-mail'
          _td do
            _input name: 'email', value: @email, required: true, type: 'email',
              disabled: @filed
          end
        end
      end

      _input.btn.btn_primary value: 'File', type: 'submit', ref: 'file',
        disabled: @submitted || (not @icla) || (not @icla.filename)
    end
  end

  # on initial display, default various fields based on headers, and update
  # state
  def mounted()
    if not @iclas.empty?
      @disabled = false
    else
      @disabled = true
      # construct arguments to fetch
      args = {
        method: 'get',
        credentials: 'include',
        headers: {'Content-Type' => 'application/json'}
      }
      fetch('../../iclas.json', args).then do |response|
        response.json().then do |json|
          @iclas = json
          @disabled = true
        end
      end
    end

    name = @@headers.name || ''

    # reorder name if there is a single comma present
    parts = name.split(',')
    if parts.length == 2 and parts[1] !~ /^\s*(jr|ph\.d)\.?$/i
      name = "#{parts[1].strip()} #{parts[0]}"
    end

    @realname = name
    @pubname = name
    @search = name
    @email = @@headers.from

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
    # TODO: why not used?
    _valid = %w(pubname email).all? do |name|
      document.querySelector("input[name=#{name}]").validity.valid
    end

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

  # when leaving an input field, trigger change event (for Safari)
  def onblur(event)
    jQuery(event.target).trigger(:change)
  end

  # handle ICLA form submission
  def file(_event)
    setTimeout 0 do
      @submitted = true
      @filed = true
    end
  end

  # when tasks complete (or are aborted) reset form
  def status_update(_event)
    @submitted = false
    @filed = false
  end
end
