class CommitterSearch < React
  def initialize
    @list = []
    @ready = false
    @search = ''
    @committers = []
  end

  def componentDidMount()
    Polyfill.require(%w(Promise fetch)) do
      fetch('committer/index.json').then do |response|
        response.json().then do |committers|
          @ready = true
          @committers = committers
          search = @search
          self.change(target: {value: search}) unless search.empty?
        end
      end
    end
  end

  def change(event)
    console.log('change')
    @search = event.target.value

    search = @search.downcase().split(' ')

    list = []
    @list = list
    @committers.each do |person|
      if 
        search.all? {|part|
          person.id.include? part or
          person.name.downcase().include? part or
          person.mail.any? {|mail| mail.include? part}
        }
      then
        list << person
      end
    end
  end

  def render
    _label 'Search:', for: 'search-text'
    _input.search_text! autofocus: true, value: @search, onChange: self.change

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
          _table do
            _thead do
              _tr do
                _th 'id'
                _th 'name'
                _th 'email'
              end
            end

            _tbody do
              list.each do |person|
                _tr do
                  _td {_a person.id, href: "committer/#{person.id}"}

                  if person.member
                    _td {_b person.name}
                  else
                    _td person.name
                  end

                  _td person.mail.first
                end
              end
            end
          end
        end
      end
    end
  end
end
