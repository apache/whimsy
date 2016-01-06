class ICLA < React
  def initialize
    @filed = false
    @checked = nil
    @submitted = false
  end

  def render
    _form action: '../../actions/icla', method: 'post', onSubmit: self.file do
      _table.form do
        _tr do
          _th 'Real Name'
          _td do
            _input name: 'realname', value: @realname, required: true,
               disabled: @filed
          end
        end

        _tr do
          _th 'Public Name'
          _td do
            _input name: 'pubname', value: @pubname, required: true,
              disabled: @filed, onFocus: -> {@pubname ||= @realname}
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
              pattern: '[a-zA-Z][-\w]+(\.[a-z]+)?', onFocus: self.genfilename,
              disabled: @filed
          end
        end
      end

      _input.btn.btn_primary value: 'File', type: 'submit', ref: 'file'
    end

    _form do
      _table.form do
        _tr do
          _th 'User ID'
          _td do
            _input name: 'user', value: @user, onBlur: self.validate_userid
          end
        end

        _tr do
          _th 'PMC'
          _td do
            _input name: 'pmc', value: @pmc
          end
        end

        _tr do
          _th 'Podling'
          _td do
            _input name: 'podling', value: @podling
          end
        end

        _tr do
          _th 'Vote Link'
          _td do
            _input type: 'url', name: 'votelink', value: @votelink
          end
        end
      end

      _button.btn.btn_primary 'Request Account', ref: 'acreq',
        onClick: self.request_account
    end
  end

  # on initial display, default various fields based on headers, and update
  # state 
  def componentDidMount()
    @realname = @@headers.name
    @email = @@headers.from
    self.componentDidUpdate()
  end

  # as fields change, enable/disable the associated buttons and adjust
  # input requirements.
  def componentDidUpdate()
    # ICLA file form
    valid = %w(realname pubname email filename).all? do |name|
      document.querySelector("input[name=#{name}]").validity.valid
    end

    $file.disabled = !valid or @filed or @submitted

    # new account request form
    valid = true
    %w(user pmc podling votelink).each do |name|
      input = document.querySelector("input[name=#{name}]")
      input.required = @user && !@user.empty?
      input.required = false if name == 'podling' and @pmc != 'incubator'
      valid &= input.validity.valid
    end

    $acreq.disabled = !valid or !@user or !@filed
  end

  # generate file name from the public name
  def genfilename()
    @filename ||= @pubname.downcase().gsub(/\W/, '-')
  end

  # handle ICLA form submission
  def file(event)
    @submitted = true

    @@submit.call(event).then {|response|
      @filed = true
      @submitted = false
      alert response.result
    }.catch {
      @filed = false
      @submitted = false
    }
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

  # show new account request window with fields filled in
  def request_account()
    params = %w{email user pmc podling votelink}.map do |name|
      "#{name}=#{encodeURIComponent(self.state[name])}"
    end

    window.parent.frames.content.location.href = 
      "https://id.apache.org/acreq/members/?" + params.join('&')
  end
end
