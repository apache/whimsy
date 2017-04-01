class MemApp < React
  def initialize
    @received = []
    @disabled = true
  end

  def render
    _h4 'Membership Application'

    _form method: 'post', action: '../../tasklist/memapp', target: 'content' do
      _input type: 'hidden', name: 'message'
      _input type: 'hidden', name: 'signature', value: @@signature

      _table.form do
        _tr do
          _td do
            _label 'Public Name', for: 'pubname'
          end

          _td do
            _select id: 'availid', name: 'availid', onChange: self.setid do
              _option value: '', selected: true
              @received.each do |line|
                next unless line.apply == 'no'
                _option line.name, value: line.id
              end
            end
          end
        end

        _tr do
          _td do
            _label 'Full Name', for: 'fullname'
          end
          _td do
            _input type: :text, name: 'fullname', id: 'fullname', value: @name
          end
        end

        _tr do
          _td do
            _label 'Address', for: 'addr'
          end
          _td do
            _textarea rows: 5, name: 'addr', id: 'addr'
          end
        end

        _tr do
          _td do
            _label 'Country', for: 'country'
          end
          _td do
            _input type: :text, name: 'country', id: 'country'
          end
        end

        _tr do
          _td do
            _label 'Telephone', for: 'tele'
          end
          _td do
            _input type: :text, name: 'tele', id: 'tele'
          end
        end

        _tr do
          _td do
            _label 'Fax', for: 'fax'
          end
          _td do
            _input type: :text, name: 'fax', id: 'fax'
          end
        end

        _tr do
          _td do
            _label 'E-Mail', for: 'email'
          end
          _td do
            _input type: :email, name: 'email', id: 'email', value: @email
          end
        end

        _tr do
          _td do
            _label 'File Name', for: 'filename'
          end
          _td do
            _input type: :text, name: 'filename', id: 'filename',
              value: @filename
          end
        end
      end

      _input.btn.btn_primary value: 'File', type: 'submit', disabled: @disabled
    end
  end

  # on initial display, default email and fetch memapp-received.txt
  def componentDidMount()
    @email = @@headers.from

    jQuery.getJSON('../../memapp.json') do |result|
      @received = result.received
    end
  end

  def setid(event)
    id = event.target.value
    @received.each do |line|
      if line.id == id
        @name = line.name
        @filename = asciize(line.name).downcase().gsub(/\W+/, '-')
        @disabled = false
      end
    end
  end
end
