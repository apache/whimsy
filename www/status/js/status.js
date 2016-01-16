$(function() {
        
  function list(status, prefix, container) {
    var items = Object.keys(status);

    items.sort(function (a, b) {
      return a.toLowerCase().localeCompare(b.toLowerCase());
    });

    items.forEach(function(item) {
      var value = status[item];
      var anchor = $('<a>').addClass('list-group-item').text(item).
        addClass('alert-' + value.level).
        attr('href', '#' + prefix + item).
        attr('data-toggle', 'collapse');
      anchor.append($('<i>').addClass('glyphicon').
        addClass('glyphicon-chevron-right'));
      if (value.title) anchor.attr('title', value.title);
      var div = $('<div>').addClass('list-group').addClass('collapse').
        attr('id', prefix + item);

      if (!value.data) {
      } else if (Array.isArray(value.data)) {
        value.data.forEach(function(subitem) {
          div.append($('<a>').addClass('list-group-item').
            text(subitem.toString()));
        });
      } else if (typeof value.data == 'object') {
        list(value.data, prefix + item, div);
      } else {
        div.append($('<a>').addClass('list-group-item').
          text(value.data.toString()));
      }

      container.append(anchor);
      container.append(div);
    });
  }


  $.get('status.json', function(status) {
    $('.well').text('');
    list(status.data, '', $('.well'));

    $('.list-group-item').on('click', function() {
      $('.glyphicon', this)
        .toggleClass('glyphicon-chevron-right')
        .toggleClass('glyphicon-chevron-down');
    });

  });

});
