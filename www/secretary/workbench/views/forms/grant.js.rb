class Grant < Vue
  def initialize
    @filed = false
    @submitted = false
  end

  def render
    _h4 'Grant'

    _div.buttons do
      _button 'clear form', disabled: @filed, onClick: lambda {@name = @email = ''}
    end

    _form method: 'post', action: '../../tasklist/grant', target: 'content' do
      _input type: 'hidden', name: 'message'
      _input type: 'hidden', name: 'selected'
      _input type: 'hidden', name: 'signature', value: @@signature

      _table.form do
        _tr do
          _th 'From'
          _td do
            _input name: 'company', value: @company, required: true,
               disabled: @filed
          end
        end

        _tr do
          _th 'For'
          _td do
            _textarea name: 'description', value: @description, rows: 5,
              required: true, disabled: @filed
          end
        end

        _tr do
          _th 'Signed By'
          _td do
            _input name: 'name', value: @name, required: true, disabled: @filed
          end
        end

        _tr do
          _th 'E-mail'
          _td do
            _input name: 'email', value: @email, required: true, type: 'email',
              disabled: @filed
          end
        end

        _tr do
          _th 'File Name'
          _td do
            _input name: 'filename', value: @filename, required: true,
              pattern: '[a-zA-Z][-\w]+(\.[a-z]+)?', disabled: @filed
          end
        end

        _tr do
          _th 'Project'
          _td do
            _select name: 'project', value: @project, disabled: @filed do
              _option ''
              @@projects.each do |project|
                _option project
              end
            end
          end
        end
      end

      _input.btn.btn_primary value: 'File', type: 'submit', ref: 'file'
    end
  end

  # on initial display, default various fields based on headers, and update
  # state
  def mounted()
    name = @@headers.name || ''

    # reorder name if there is a single comma present
    parts = name.split(',')
    if parts.length == 2 and parts[1] !~ /^\s*(jr|ph\.d)\.?$/i
      name = "#{parts[1].strip()} #{parts[0]}"
    end

    @name = name
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
    # Grant file form
    valid = %w(company name email filename).all? do |name|
      document.querySelector("input[name=#{name}]").validity.valid
    end

    valid &= document.querySelector("textarea[name=description]").validity.valid

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

  # when leaving an input field, trigger change event (for Safari)
  def onblur(event)
    jQuery(event.target).trigger(:change)
  end

  # handle Grant form submission
  def file(event)
    setTimeout 0 do
      @submitted = true
      @filed = true
    end
  end

  # when tasks complete (or are aborted) reset form
  def status_update(event)
    @submitted = false
    @filed = false
  end
end
