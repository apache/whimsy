class MemApp < Vue
  def initialize
    @received = []
    @filed = false
    @disabled = true
  end

  def render
    _h4 'Membership Application'

    _form method: 'post', action: '../../tasklist/memapp', target: 'content' do
      _input type: 'hidden', name: 'message'
      _input type: 'hidden', name: 'selected'
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
            _input type: :text, name: 'fullname', id: 'fullname', value: @name,
              disabled: @filed, onChange: self.changeFullName
          end
        end

        _tr do
          _td do
            _label 'File Name', for: 'filename'
          end
          _td do
            _input type: :text, name: 'filename', id: 'filename',
              value: @filename, disabled: @filed
          end
        end
      end

      _input.btn.btn_primary value: 'File', type: 'submit', disabled: @disabled
    end
  end

  # on initial display, wire up form, default email and fetch
  # memapp-received.txt
  def mounted()
    # wire up form
    jQuery('form')[0].addEventListener('submit', self.file)
    jQuery('input[name=message]').val(window.parent.location.pathname)
    jQuery('input[name=selected]').val(decodeURIComponent(@@selected))

    # default email
    @email = @@headers.from

    # fetch memapp-received information
    jQuery.getJSON('../../memapp.json') do |result|
      @received = result.received
    end

    # watch for status updates
    window.addEventListener 'message', self.status_update
  end

  # when fullname changes, change filename
  def changeFullName(event)
    @name = event.target.value
    @filename = asciize(event.target.value).downcase().gsub(/\W+/, '-')
  end

  # when id is selected, default full name and filename
  def setid(event)
    id = event.target.value
    @received.each do |line|
      if line.id == id
        @name = line.name
        @filename = asciize(line.name).downcase().gsub(/\W+/, '-')
        @disabled = false

        if @@headers.from =~ /@apache.org$/
          jQuery.getJSON('../../email.json', id: id) do |result|
            @email = result.email
          end
        end
      end
    end
  end

  # handle membership application form submission
  def file(event)
    setTimeout 0 do
      @disabled = true
      @filed = true
    end
  end

  # when tasks complete (or are aborted) reset form
  def status_update(event)
    @disabled = false
    @filed = false
  end
end
