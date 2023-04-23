#
# Add People to a PMC
#

class PMCAdd < Vue
  mixin ProjectAdd
  options add_tag: "pmcadd", add_action: 'actions/committee'

  def initialize
    @people = []
  end

  def render
    _div.modal.fade id: $options.add_tag, tabindex: -1 do
      _div.modal_dialog do
        _div.modal_content do
          _div.modal_header.bg_info do
            _button.close 'x', data_dismiss: 'modal'
            _h4.modal_title 'Add People to the ' + @@project.display_name +
              ' Project'
            _p {
              _br
              _b 'N.B'
              _br
              _ 'To add existing committers to the PMC, please cancel this dialog. Select the committer from the list and use the Modify button.'
            }
          end

          _div.modal_body do
            _div.container_fluid do

              unless @people.empty?
                _table.table do
                  _thead do
                    _tr do
                      _th 'id'
                      _th 'name'
                      _th 'email'
                    end
                  end
                  _tbody do
                    @people.each do |person|
                      _tr do
                        _td person.id
                        _td person.name
                        _td person.mail[0]
                      end
                    end
                  end
                end
              end

              _CommitterSearch add: self.add,
                exclude: @@project.roster.keys().
                  concat(@people.map {|person| person.id})

              _p do
                _br
                _b do
                  _ 'Before adding a new PMC member, '
                  _a 'the PMC must approve the new member by VOTE or consensus.',
                  _a 'You can use the following link to find the thread on the private list'
                  _a 'and copy it into the text field below.'
                    href: 'https://lists.apache.org/list?private@' + @@project.display.name + '.apache.org:lte=6M:'
                  _ ' (the PMC private@ mailing list).'
                end
                _label do
                  _span 'Enter the link to the approval VOTE or consensus thread:'
                  _input type: 'text', value:@votelink
                end
              end
            end
          end

          _div.modal_footer do
            _span.status 'Processing request...' if @disabled

            _button.btn.btn_default 'Cancel', data_dismiss: 'modal',
              disabled: @disabled

            plural = (@people.length > 1 ? 's' : '')

            _button.btn.btn_primary "Add as committer#{plural}",
              data_action: 'add commit',
              onClick: self.post, disabled: (@people.empty?)

            _button.btn.btn_primary 'Add to PMC', onClick: self.post,
              data_action: 'add pmc info commit',
              disabled: (@people.empty? or not @notice_elapsed)
          end
        end
      end
    end
  end
end
