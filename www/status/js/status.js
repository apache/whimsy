$(function() {
        
  // convert status into .list-group-item and .list-group elements, and
  // insert into the container.  Use prefix when generating ids.
  function listGroup(status, prefix, container) {
    var items = Object.keys(status);

    // sort items in a case insensitive manner
    items.sort(function (a, b) {
      return a.toLowerCase().localeCompare(b.toLowerCase());
    });

    items.forEach(function(item) {
      var value = status[item];

      // build an anchor line
      var anchor = $('<a>').addClass('list-group-item').
        text(value.text || item).
        addClass('alert-' + value.level).
        attr('href', '#' + prefix + item).
        attr('data-toggle', 'collapse');
      anchor.append($('<i>').addClass('glyphicon').
        addClass('glyphicon-chevron-right'));
      if (value.title) anchor.attr('title', value.title);
      var div = $('<div>').addClass('list-group').addClass('collapse').
        attr('id', prefix + item);

      // default data to mtime, if present
      if (!value.data && value.mtime) {
        value.data = "Last updated " +
          new Date(Date.parse(value.mtime)).toLocaleString()
      }

      // build nested content (recursively if value.data is an object)
      if (!value.data) {
        div.append($('<a>').addClass('list-group-item').
          append($('<em>empty</em>')));
      } else if (Array.isArray(value.data)) {
        value.data.forEach(function(subitem) {
          div.append($('<a>').addClass('list-group-item').
            text(subitem.toString()));
        });
      } else if (typeof value.data == 'object') {
        listGroup(value.data, prefix + item + '-', div);
      } else {
        div.append($('<a>').addClass('list-group-item').
          text(value.data.toString()));
      }

      // hot link text children
      if (value.href) {
        div.children('a:not(.data-toggle)').attr('href', value.href);
      }
 
      // provide ISO-8601 formatted GMT time as a tooltip
      if (value.mtime && !value.title) {
        div.children('a:not(.data-toggle)').attr('title', value.mtime);
      }

      // append each to the container
      container.append(anchor);
      container.append(div);
    });
  }

  // fetch status from the server
  $.get('status.json', function(status) {
    // remove 'loading...' line
    $('.list-group-root').text('');

    // replace with status
    listGroup(status.data, '', $('.well'));

    // make toggles active
    $('.list-group-item').on('click', function() {
      var glyphicon = $('.glyphicon', this);

      // update location hash in the url
      if (glyphicon.hasClass('glyphicon-chevron-right')) {
        history.replaceState(null, null, $(this).attr('href'));
      }

      // toggle the content
      glyphicon.
        toggleClass('glyphicon-chevron-right').
        toggleClass('glyphicon-chevron-down');
    });

    // if hash is present in location, show that item
    if (location.hash) {
      // find element
      var element = $('a[href="' + location.hash + '"]');

      // expand all parents
      element.parents('.list-group').each(function() {
        $('a[href="#' + this.getAttribute('id') + '"]').trigger('click');
      });

      // expand this item
      element.trigger('click');

      // scroll to this item
      $('html, body').animate({scrollTop: element.offset().top}, 1000);
    }

  });

});
