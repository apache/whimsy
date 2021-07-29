class IclaSearch < Vue
  def initialize
    @list = []
    @ready = false
    @search = ''
    @iclas = []
  end

  def mounted()
    # start with (possibly stale) data from local storage when available
    ls_iclas = localStorage.getItem('roster-iclas')
    if ls_iclas
      @iclas = JSON.parse(ls_iclas)
      @ready = true
      self.change(target: {value: @search}) unless @search.empty?
    end

    # load fresh data from the server
    Polyfill.require(%w(Promise fetch)) do
      fetch('icla/index.json', credentials: 'include').then {|response|
        response.json().then do |iclas|
          @iclas = iclas
          @ready = true
          self.change(target: {value: @search}) unless @search.empty?
          localStorage.setItem('roster-iclas', @iclas.inspect)
        end
      }.catch {|error|
        console.log error
      }
    end
  end

  def change(event)
    @search = event.target.value

    search = @search.downcase().split(' ')

    list = []
    @list = list
    @iclas.each do |icla|
      if
        search.all? {|part|
          icla.name.downcase().include? part or
          icla.mail.downcase().include? part
        }
      then
        list << icla
      end
    end
  end

  def render
    _div.form_group do
      _label.control_label.col_sm_3 'Search for name or email', :for =>  'search-text'
      _div.col_sm_9 do
        _div.input_group do
          _input.form_control autofocus: true, value: @search,
            onInput: self.change
          _span.input_group_addon do
            _span.glyphicon.glyphicon_user aria_label: "Committer ID or name"
          end
        end
      end
    end

    if @search.length
      if not @ready
        _p 'loading...'

      else
        list = @list

        if list.length == 0
          _p 'none found'
        elsif list.length > 99
          _p "#{list.length} entries match"
        else
          hasICLA = list.first.iclaFile
          _table.table.table_hover do
            _thead do
              _tr do
                _th 'public name'
                _th 'email'
                _th 'ICLA' if hasICLA
              end
            end

            _tbody do
              list.each do |icla|
                _tr do
                  _td icla.name
                  _td icla.mail
                  if hasICLA
                    # iclapath already ends in /
                    _td { _a icla.claRef, href: "#{@@iclapath}#{icla.iclaFile}" }
                  end
                end
              end

            end
          end

        end
      end
    end
  end

end
