class EmeritusRequest < Vue
  def initialize
    @filed = false
    @filename = ''
    @disabled = false
    @search = ''
    @members = []
    @member = nil
  end

  def mounted
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
    @filename = self.gen_file_name(name)
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
          if search.all? { |part| member.id.include? part or member.name.downcase().include? part }
            _li do
              _input type: :radio, name: 'member', value: member.id, id: member.id, onClick: lambda {
                @member = member
                @filename = self.gen_file_name(member.name)
              }
              _label member.name, for: member.id
            end
          end
        end
      end
    end

    _form method: 'post', action: '../../tasklist/emeritus-request', target: 'content' do
      _input type: :hidden, name: 'message'
      _input type: :hidden, name: 'selected'
      _input type: :hidden, name: 'signature', value: @@signature

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

  def updated
    jQuery('input[name=selected]').val(decodeURI(@@selected))
  end

  def gen_file_name(name)
    return asciize(name.strip()).downcase().gsub(/\W+/, '-')
  end
end