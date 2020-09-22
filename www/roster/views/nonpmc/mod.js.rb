#
# Modify People's role in a project
#

class NonPMCMod < Vue
  mixin ProjectMod
  options mod_tag: "pmcmod", mod_action: 'actions/nonpmc'

  def initialize
    @people = []
  end

  def render
    _div.modal.fade.pmcmod! tabindex: -1 do
      _div.modal_dialog do
        _div.modal_content do
          _div.modal_header.bg_info do
            _button.close 'x', data_dismiss: 'modal'
            _h4.modal_title "Modify People's Roles in the " +
              @@project.display_name + ' Project'
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

            # show add to Committee button only if every person is not on the Committee
            if @people.all? {|person| !@@project.members.include? person.id}
              _button.btn.btn_primary "Add to Committee",
                data_action: 'add pmc info',
                onClick: self.post, disabled: @people.empty?
            end

            # remove from all relevant locations
            remove_from = ['commit']
            if @people.any? {|person| @@project.members.include? person.id}
              remove_from << 'info'
            end
            if @people.any? {|person| @@project.ldap.include? person.id}
              remove_from << 'pmc'
            end

            _button.btn.btn_primary 'Remove from project', onClick: self.post,
              data_action: "remove #{remove_from.join(' ')}"

            if @people.all? {|person| @@project.members.include? person.id}
              _button.btn.btn_warning "Remove from Committee only",
                data_action: 'remove pmc info',
                onClick: self.post
            end
          end
        end
      end
    end
  end
end
