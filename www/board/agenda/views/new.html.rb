#
# Post a new agenda
#

_html do
  _base href: @base
  _title 'ASF Board Agenda'
  _link rel: 'stylesheet', href: "stylesheets/app.css?#{@cssmtime}"
  _meta name: 'viewport', content: 'width=device-width, initial-scale=1.0'

  _div.container.new_agenda! do
    if @next_month and not @next_month.empty?
      _div.commented do
        _h4 'Committees expected to report next month, and why:'
        _pre.commented @next_month
      end
    end

    _form method: 'post',  action: @meeting.strftime("%Y-%m-%d/") do

      _div.text_center do
        _button.btn.btn_primary 'Post', disabled: @disabled
      end

      _textarea.form_control @agenda, name: 'agenda',
        rows: [@agenda.split("\n").length, 20].max
    end
  end
end
