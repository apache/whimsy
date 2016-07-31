_html do
  _head_ do
    _meta name: "viewport", content: 'width=device-width', initial_scale: 1
    _style_ %{
      div:empty {display: none}
    }
  end

  _body do
    _div.alert

    _form_ method: 'post' do
      _button.btn.btn_primary 'Send email', type: 'submit', disabled: true
    end

    _p_ 'loading'

    _script %q{
      var button = document.querySelector('button');
      var alert = document.querySelector('.alert');
      var form = document.querySelector('form');

      jQuery.getJSON('feedback.json', function(data) {
        data.forEach(function(message) {
          var h1 = document.createElement('h1');
          h1.setAttribute('id', message.title);
          h1.textContent = message.title;

          var input = document.createElement('input');
          input.setAttribute('type', 'checkbox');
          input.setAttribute('name', 'checked[' +
            message.title.replace(/\s/g, '_') + ']');
          input.checked = !message.sent;
          h1.insertBefore(input, h1.firstChild);

          var pre = document.createElement('pre');
          pre.textContent = message.mail;
          form.appendChild(h1);
          form.appendChild(pre);
        });

        document.querySelector('p').remove();

        button.disabled = false;
      });

      button.addEventListener('click', function(event) {
        event.preventDefault();
        button.disabled = true;
        jQuery.ajax('feedback.json', {
          method: 'POST',
          data: $(form).serialize(),

          success: function(event) {
            alert.classList.add('alert-success');
            alert.textContent = 'emails sent';
          },

          error: function(event) {
            alert.classList.add('alert-danger');
            alert.textContent = event.statusText;
          }
        });
      });
    }
  end
end
