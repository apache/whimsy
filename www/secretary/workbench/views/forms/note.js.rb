#
# Add/edit message notes
#

class Note < Vue
  def render
    _div.partmail! do
      _h3 'Note'
      _textarea value: @notes, name: 'notes'

      _input.btn.btn_primary value: 'Save', type: 'submit',
        onClick: submit
    end
  end

  def created()
    @@headers.secmail ||= {}
    @@headers.secmail.notes ||= ''
    @notes = @@headers.secmail.notes
  end

  def submit()
    data = {
      message: window.parent.location.pathname,
      notes: @notes
    }

    HTTP.post('../../actions/note', data).then {|result|
      window.location.reload()
    }.catch {|message|
      alert message
    }
  end
end
