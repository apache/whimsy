_html do
  _body do
    _p 'loading'

    _script %{
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
      });
    }
  end
end
