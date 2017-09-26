#
# Post a new agenda
#

_html do
  _base href: @base
  _title 'ASF Board Agenda'
  _link rel: 'stylesheet', href: "../stylesheets/app.css?#{@cssmtime}"
  _meta name: 'viewport', content: 'width=device-width, initial-scale=1.0'

  _div.container do
    _form method: 'post',  action: @meeting.strftime("%Y-%m-%d/") do

      _div.text_center style: 'margin: 1em' do
        _button.btn.btn_primary 'Post'
      end

      _textarea.form_control @agenda, name: 'agenda',
        rows: [@agenda.split("\n").length, 20].max,
        style: 'overflow: hidden'
    end
  end
end
