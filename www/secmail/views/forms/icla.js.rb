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
            _input name: 'userid', value: @userid
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

      _button.btn.btn_primary 'Request Account', disabled: true
    end
  end

  # on initial display, update state
  def componentDidMount()
    # self.componentDidUpdate()
  end

  # as fields change, enable/disable the file button
  def componentDidUpdate()
    valid = %w(realname pubname email filename).all? do |name|
      return document.querySelector("input[name=#{name}]").validity.valid
    end

    $file.disabled = !valid
  end

  # generate file name from the public name
  def genfilename()
    @filename ||= @pubname.downcase().gsub(/\W/, '-') + '.pdf'
  end
end
