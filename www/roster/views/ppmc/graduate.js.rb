##   Licensed to the Apache Software Foundation (ASF) under one or more
##   contributor license agreements.  See the NOTICE file distributed with
##   this work for additional information regarding copyright ownership.
##   The ASF licenses this file to You under the Apache License, Version 2.0
##   (the "License"); you may not use this file except in compliance with
##   the License.  You may obtain a copy of the License at
## 
##       http://www.apache.org/licenses/LICENSE-2.0
## 
##   Unless required by applicable law or agreed to in writing, software
##   distributed under the License is distributed on an "AS IS" BASIS,
##   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
##   See the License for the specific language governing permissions and
##   limitations under the License.

#
# Draft an "Establish" resolution for a new PMC
#

class PPMCGraduate < Vue
  def initialize
    @owners = []
  end

  def render
    _button.btn.btn_info 'Draft graduation resolution',
      data_target: '#graduate', data_toggle: 'modal'

    _div.modal.fade.graduate! tabindex: -1 do
      _div.modal_dialog do
        _div.modal_content do
          _form method: 'post', action: "ppmc/#{@@ppmc.id}/establish" do
            _div.modal_header.bg_info do
              _button.close 'x', data_dismiss: 'modal'
              _h4.modal_title "Establish Apache #{@project}"
            end

            _div.modal_body do
              _p do
                _b "Once you've drafted this resolution, make sure you review it on the podling's private list"
              end
              _p do
                _b 'Complete this sentence: '
                _span "Apache #{@project} consists of software related to"
              end

              _textarea name: 'description', value: @description, rows: 4

              _p { _b 'Choose a chair' }

              _select name: 'chair' do
                @owners.each do |person|
                  _option person.name, value: person.id,
                    selected: person.id == @@id
                end
              end
            end

            _div.modal_footer do
              _span.status 'Processing request...' if @disabled
              _button.btn.btn_default 'Cancel', data_dismiss: 'modal'
              _button.btn.btn_primary 'Draft Resolution'
            end
          end
        end
      end
    end
  end

  def resize(textarea)
    textarea.css('height', 0)
    textarea.css('height', Math.max(50, textarea[0].scrollHeight)+'px')
  end

  def mounted()
    textarea = jQuery('#graduate textarea')

    jQuery('#graduate').on('show.bs.modal') do |event|
      @project = @@ppmc.display_name
      @description = @@ppmc.description.gsub(/\s+/, ' ').strip().
        sub(/^(Apache )?#{@@ppmc.display_name}\s(is )?/, '').sub(/\.$/, '')

      self.resize(textarea)

      @owners = @@ppmc.owners.
        map {|id| {id: id, name: @@ppmc.roster[id].name}}.
        sort_by {|person| person.name}
    end

    jQuery('#graduate').on('shown.bs.modal') do |event|
      self.resize(textarea)
    end

    textarea.on('keyup') do |event|
      self.resize(textarea)
    end
  end

  def updated()
    self.resize(jQuery('#graduate textarea'))
  end
end
