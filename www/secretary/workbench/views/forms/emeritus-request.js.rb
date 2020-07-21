class EmeritusRequest < Vue
  def initialize
    # TODO: update @filed = true on submit and related reset
    @filed = false
    @filename = ''
    @disabled = false
    @search = ''
    @members = []
    @availid = ''
  end

  def mounted
    jQuery('input[name=selected]').val(decodeURIComponent(@@selected))
    jQuery('input[name=message]').val(window.parent.location.pathname)
    if not @members.empty?
      @disabled = false
    else
      @disabled = true
      fetch('../../members.json', {method: 'get', credentials: 'include', headers: {accept: 'application/json'}})
          .then do |response|
        response.json().then do |json|
          @members = json
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
    @search = name
  end

  def render
    _h4 'Member Emeritus Request'

    _form.form do
      _h5 'Search'
      _table.form do
        _tr do
          _input value: @search
        end
      end
    end

    if @search.length >= 3 and not @members.empty?
      search = @search.downcase().split(' ')
      _ul.icla_search do
        @members.each do |member|
          availid = member.id
          name = member.name
          if search.all? { |part| availid.include? part or name.downcase().include? part }
            _li do
              _input type: :radio, name: 'search', id: availid, onClick: lambda {
                @availid = availid
                @filename = availid
                @disabled = false
              }
              _label name, for: availid
            end
          end
        end
      end
    end

    _form method: 'post', action: '../../tasklist/emeritus-request', target: 'content' do
      _input type: :hidden, name: 'message'
      _input type: :hidden, name: 'selected'
      _input type: :hidden, name: 'signature', value: @@signature
      _input type: :hidden, name: 'availid', value: @availid

      _table.form do
        _tr do
          _th 'File Name'
          _td do
            _input type: :text, name: 'filename', value: @filename, required: true, disabled: @filed,
                   pattern: '[a-zA-Z][-\w]+(\.[a-z]+)?'
          end
        end
      end

      _input.btn.btn_primary value: 'File', type: :submit, disabled: @disabled
    end
  end

end
