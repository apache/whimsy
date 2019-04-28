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

class Summary < Vue
  def initialize
    @disabled = true
  end

  # default attributes for the button associated with this form
  def self.button
    {
      text: 'send summary',
      class: 'btn_danger',
      data_toggle: 'modal',
      data_target: '#summary-form'
    }
  end

  def render
    _ModalDialog.summary_form!.wide_form color: 'commented' do
      _h4.commented 'Send out meeting summary to committers'

      _textarea.summary_text!.form_control rows: 17, tabIndex: 1,
        placeholder: 'committers summary', value: @summary, disabled: @disabled

      _button.btn_default 'Cancel', type: 'button', data_dismiss: 'modal'
      _button.btn_primary 'Send', type: 'button', onClick: self.send,
        disabled: @disabled
    end
  end

  # autofocus on summary text; fetch summary
  def mounted()
    @summary = ''
    jQuery('#summary-form').on 'show.bs.modal' do
      retrieve "summary/#{Agenda.title}", :text do |summary|
        document.getElementById("summary-text").focus()
        @disabled = false
        @summary = summary
        jQuery('#summary-text').animate(scrollTop: 0)
      end
    end
  end

  def send(event)
    @disabled = true
    post 'summary', agenda: Agenda.file, text: @summary do |response|
      Minutes.load response.minutes
      @disabled = false
      jQuery('#summary-form').modal(:hide)
      document.body.classList.remove('modal-open')
    end
  end
end
