#
# Create a new Podling
#

class PPMCNew < Vue
  def initialize
    @mentors = []
    @sponsor = 'incubator'
    @startdate = Date.new().toISOString().slice(0,10)
  end

  def render
    _h2 'Create a new Podling'

    _form.data_entry do
      _div.form_group do
        _label 'Podling name', for: 'name'
        _input.form_control id: 'name', name: 'name', value: @name,
          onInput: setname
        _small.form_text.text_muted 'Typically capitalized, as in a book title'
      end

      _div.form_group do
        _label 'Podling identifier', for: 'resource'
        _input.form_control id: 'resource', name: 'resource', value: @resource
        _small.form_text.text_muted 'Resource identifier, all lower case'
      end

      _div.form_group do
        _label 'Sponsor', for: 'sponsor'
        _select.form_control id: 'sponsor', name: 'sponsor', value: @sponsor do
          @@pmcsAndBoard.each do |pmc|
            _option pmc
          end
        end
        _small.form_text.text_muted 'Either a PMC or board'
      end

      _div.form_group do
        _label 'Description', for: 'description'
        _textarea.form_control id: 'description', name: 'description',
          value: @description, rows: 6
        _small.form_text.text_muted 'Freeform text'
      end

      _div.form_group do
        _label 'Start date', for: 'startdate'
        _input.form_control id: 'startdate', name: 'startdate',
          value: @startdate
        _small.form_text.text_muted 'Format: yyyy-mm-dd'
      end

      _div.form_group do
        _label 'Champion', for: 'champion'
        _input.form_control id: 'champion', name: 'champion', value: @champion,
          disabled: true
        _small.form_text.text_muted 'Officers and ASF Members'
        _CommitterSearch include: @@officersAndMembers, add: addChampion
      end

      _div.form_group do
        _label 'Mentors', for: 'mentors'
        _input.form_control id: 'mentors', name: 'mentors',
          value: @mentors.join(','), disabled: true
        _small.form_text.text_muted 'IPMC members'
        _CommitterSearch include: @@ipmc, add: addMentor, exclude: @mentors
      end

      _div.form_group do
        _button.btn.btn_primary 'submit', disabled: (not @name or
          not @resource or not @description or
          @startdate !~ /^\d\d\d\d-\d\d-\d\d/ or not @champion or
          @mentors.empty?)
      end
    end
  end

  # when name changes, update resource to match
  def setname(event)
    @name = event.target.value
    @resource = @name.downcase().gsub(/\W/, '')
  end

  # set champion based on search
  def addChampion(person)
    @champion = person.id
  end

  # add mentor based on search
  def addMentor(person)
    @mentors << person.id
  end
end
