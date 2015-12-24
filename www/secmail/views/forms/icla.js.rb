class ICLA < React
  def render
    _form action: '../../actions/icla', method: 'post', onSubmit: @@submit do
      _table.form do
        _tr do
          _th 'Real Name'
          _td do
            _input name: 'realname', value: @realname, required: true
          end
        end

        _tr do
          _th 'Public Name'
          _td do
            _input name: 'pubname', value: @pubname, required: true,
              onFocus: -> {@pubname ||= @realname}
          end
        end

        _tr do
          _th 'E-mail'
          _td do
            _input name: 'email', value: @email, required: true, type: 'email'
          end
        end

        _tr do
          _th 'File Name'
          _td do
            _input name: 'filename', value: @filename, required: true,
              pattern: '[a-zA-Z][-\w]+(\.[a-z]+)?', onFocus: self.genfilename
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
            _input name: 'user', value: @user
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
        onClick: self.acreq
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

    $file.disabled = !valid

    # new account request form
    valid = true
    %w(user pmc podling votelink).each do |name|
      input = document.querySelector("input[name=#{name}]")
      input.required = @user && !@user.empty?
      input.required = false if name == 'podling' and @pmc != 'incubator'
      valid &= input.validity.valid
    end

    $acreq.disabled = !valid or !@user
  end

  # generate file name from the public name
  def genfilename()
    @filename ||= @pubname.downcase().gsub(/\W/, '-') + '.pdf'
  end

  # show new account request window with fields filled in
  def acreq()
    params = %w{email user pmc podling votelink}.map do |name|
      "#{name}=#{encodeURIComponent(self.state[name])}"
    end

    window.parent.frames.content.location.href = 
      "https://id.apache.org/acreq/members/?" + params.join('&')
  end
end
