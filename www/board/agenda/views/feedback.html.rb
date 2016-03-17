_html do
  _head do
    _style %{
      div:empty {display: none}
      .feedback pre {min-width: 640px; display: inline-block}
    }
  end

  _body.feedback do
    _div.alert

    _form_ method: 'post' do
      _button.btn.btn_primary 'Send email', type: 'submit', disabled: true
    end

    _p_ 'loading'

    _script %{
      var button = document.querySelector('button');
      var alert = document.querySelector('.alert');

      jQuery.getJSON('feedback.json', function(data) {
        data.forEach(function(message) {
          var h1 = document.createElement('h1');
          h1.setAttribute('id', message.title);
          h1.textContent = message.title;
          var pre = document.createElement('pre');
          pre.textContent = message.mail;
          document.body.appendChild(h1);
          document.body.appendChild(pre);
        });

        document.querySelector('p').remove();

        button.disabled = false;
      });

      button.addEventListener('click', function(event) {
        event.preventDefault();
        button.disabled = true;
        jQuery.ajax('feedback.json', {
          method: 'POST',

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
