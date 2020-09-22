#
# Modify People's role in a podling
#

class PPMCMod < Vue
  mixin ProjectMod
  options mod_tag: "ppmcmod", mod_action: 'actions/ppmc'

  def initialize
    @people = []
  end

  def render
    _div.modal.fade id: $options.mod_tag, tabindex: -1 do
      _div.modal_dialog do
        _div.modal_content do
          _div.modal_header.bg_info do
            _button.close 'x', data_dismiss: 'modal'
            _h4.modal_title "Modify People's Roles in the " +
              @@project.display_name + ' Podling'
          end

          _div.modal_body do
            _div.container_fluid do
              _table.table do
                _thead do
                  _tr do
                    _th 'id'
                    _th 'name'
                  end
                end
                _tbody do
                  @people.each do |person|
                    _tr do
                      _td person.id
                      _td person.name
                    end
                  end
                end
              end
            end
          end

          _div.modal_footer do
            _span.status 'Processing request...' if @disabled

            _button.btn.btn_default 'Cancel', data_dismiss: 'modal',
              disabled: @disabled

            if @@auth.ppmc
              # show add to PPMC button only if every person is not on the PPMC
              if @people.all? {|person| !@@project.owners.include? person.id}
                _button.btn.btn_primary "Add to PPMC",
                  data_action: 'add ppmc',
                  onClick: self.post, disabled: (@people.empty?)
              end
            end

            # show add as mentor button only if every person is not a mentor
            if @@auth.ipmc
              if @people.all? {|person| !@@project.mentors.include? person.id}
                plural = (@people.length > 1 ? 's' : '')

                action = 'add mentor'
                if @people.any? {|person| !@@project.owners.include? person.id}
                  action += ' ppmc'
                end

                _button.btn.btn_primary "Add as Mentor#{plural}",
                  data_action: action, onClick: self.post,
                  disabled: (@people.empty?)
              end
            end

            # remove from all relevant locations
            remove_from = ['committer']
            if @people.any? {|person| @@project.owners.include? person.id}
              remove_from << 'ppmc'
            end
            if @people.any? {|person| @@project.mentors.include? person.id}
              remove_from << 'mentor'
            end

            _button.btn.btn_primary "Remove from project (#{remove_from.join(', ')})", onClick: self.post,
              data_action: "remove #{remove_from.join(' ')}"
          end
        end
      end
    end
  end
end
