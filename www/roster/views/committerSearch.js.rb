class CommitterSearch < Vue
  def initialize
    @list = []
    @ready = false
    @search = ''
    @committers = []
  end

  def mounted()
    if @@notinavail
      local_var = 'roster-committers-notinavail'
      url = 'committer2/index.json'
    else
      local_var = 'roster-committers'
      url = 'committer/index.json'
    end
    # start with (possibly stale) data from local storage when available
    ls_committers = localStorage.getItem(local_var)
    if ls_committers
      @committers = JSON.parse(ls_committers)
      @ready = true
      self.change(target: {value: @search}) unless @search.empty?
    end

    # load fresh data from the server
    Polyfill.require(%w(Promise fetch)) do
      fetch(url, credentials: 'include').then {|response|
        response.json().then do |committers|
          @committers = committers
          @ready = true
          self.change(target: {value: @search}) unless @search.empty?
          localStorage.setItem(local_var, @committers.inspect)
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
    @committers.each do |person|
      if
        search.all? {|part|
          if person.id
            person.id.include? part or
            person.name.downcase().include? part or
            person.mail.any? {|mail| mail.include? part} or
            person.githubUsername.any? {|ghun| ghun.downcase().include? part}
          else
            person.name.downcase().include? part or
            person.mail.include? part
          end
        }
      then
        unless @@exclude and @@exclude.include? person.id
          if not @@include or @@include.empty? or @@include.include? person.id
            list << person
          end
        end
      end
    end
  end

  def render
    _div.form_group do
      _label.control_label.col_sm_3 'Search for', for:  'search-text'
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
        search = @search.downcase().split(' ')
        list = @list

        if list.length == 0
          _p 'none found'
        elsif list.length > 99
          _p "#{list.length} entries match"
        else
          _table.table.table_hover do
            _thead do
              _tr do
                _th
                _th 'id'
                _th 'public name'
                _th 'email'
                _th 'githubUsername'
                if @@notinavail
                  _th 'ICLA'
                end
              end
            end

            _tbody do
              list.each do |person|
                _tr do
                  if person.id
                    _td "\u2795", data_id: person.id, onClick: self.select
                    _td {_a person.id, href: "committer/#{person.id}"}
                  else
                    _td "\u2795"
                    _td 'notinavail'
                  end

                  if person.member
                    _td {_b person.name}
                  else
                    _td person.name
                  end

                  if person.id
                    _td person.mail.first
                  else
                    _td person.mail
                  end

                  if person.githubUsername
                    _td person.githubUsername.join(', ')
                  else
                    _td ''
                  end
                  if @@notinavail
                    # iclapath already ends in /
                    _td { _a person.claRef, href: "#{@@iclapath}#{person.iclaFile}" }
                  end
                end
              end

              if @@add
                _tr do
                  _td "Click on \u2795 to add.", colspan: 4
                end
              end
            end
          end

        end
      end
    end
  end

  def select(event)
    if @@add
      id = event.currentTarget.dataset.id
      person = @list.find {|person| person.id == id}
      @@add.call(person)
      @search = ''
    end
  end
end
