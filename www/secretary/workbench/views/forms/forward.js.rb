class Forward < Vue
  def render
    _h4 'Forward'

    # forward message to appropriate destination
    _form.doctype method: 'POST', target: 'content' do

      _input type: 'hidden', name: 'message',
        value: window.parent.location.pathname
      _input type: 'hidden', name: 'selected', value: @@selected
      _input type: 'hidden', name: 'signature', value: @@signature

      _label do
        _input type: 'radio', name: 'destination',
          onClick: self.forward, value: 'accounting@apache.org'
        _span 'accounting'
      end

      _label do
        _input type: 'radio', name: 'destination',
          onClick: self.forward, value: 'chairman@apache.org'
        _span 'chairman'
      end

      _label do
        _input type: 'radio', name: 'destination',
          onClick: self.forward, value: 'legal-internal@apache.org'
        _span 'legal-internal'
      end

      _label do
        _input type: 'radio', name: 'destination',
          onClick: self.forward, value: 'operations@apache.org'
        _span 'operations'
      end

      _label do
        _input type: 'radio', name: 'destination',
          onClick: self.forward, value: 'president@apache.org'
        _span 'president'
      end

      _label do
        _input type: 'radio', name: 'destination',
          onClick: self.forward, value: 'trademarks@apache.org'
        _span 'trademarks'
      end
    end
  end

  def forward(event)
    form = jQuery(event.target).closest('form')
    form.attr('action', "../../tasklist/forward")
    form.submit()
  end
end
