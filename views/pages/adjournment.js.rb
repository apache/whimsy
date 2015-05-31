#
# Secretary version of Adjournment section: shows todos
#

class Adjournment < React
  def initialize
    @todos = {add: [], remove: [], establish: [], loading: true}
  end

  def render
    _section.flexbox do
      _section do
        _pre.report @@item.text

        _h3 'Post Meeting actions'

        if 
          @todos.add.empty? and @todos.remove.empty? and @todos.establish.empty?
        then
          if @todos.loading
            _em 'Loading...'
          else
            _p 'none'
          end
        end

        unless @todos.add.empty?
          _p 'Add to pmc-chairs:'
          _ul @todos.add do |person|
            _li do
              _a person.id,
                href: "https://whimsy.apache.org/roster/committer/#{person.id}"
              _ " (#{person.name})"

              resolution = Minutes.get(person.resolution)
              if resolution
                _ ' - '
                _Link text: resolution, href: self.link(person.resolution)
              end
            end
          end
        end

        unless @todos.remove.empty?
          _p 'Remove from pmc-chairs:'
          _ul @todos.remove do |person|
            _li do
              _a person.id,
                href: "https://whimsy.apache.org/roster/committer/#{person.id}"
              _ " (#{person.name})"
            end
          end
        end

        unless @todos.establish.empty?
          _p do
            _a 'Establish pmcs:', 
              href: 'https://infra.apache.org/officers/tlpreq'
          end

          _ul @todos.establish do |podling|
            _li do
              _span podling.name

              resolution = Minutes.get(podling.resolution)
              if resolution
                _ ' - '
                _Link text: resolution, href: self.link(podling.resolution)
              end
            end
          end
        end
      end

      _section do
        minutes = Minutes.get(@@item.title)
        if minutes
          _h3 'Minutes'
          _pre.comment minutes
        end
      end
    end
  end

  # find corresponding agenda item
  def link(title)
    link = nil
    Agenda.index.each do |item|
      link = item.href if item.title == title
    end
    return link
  end

  def componentDidMount()
    fetch "secretary-todos/#{Agenda.title}", :json do |todos|
      @todos = todos
    end
  end
end
