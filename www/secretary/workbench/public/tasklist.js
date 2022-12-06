var tasks = $('h3');
var spinner = $('<img src="../spinner.gif"/>');
var disposition = null;
var headers = null;

// Load fetch shim, if needed (e.g., by Safari)
if (typeof fetch === 'undefined') {
  var script = document.createElement('script');
  script.type = 'text/javascript';
  script.src = '../fetch.js';
  $('head').append(script);
};

// Conditionally process next task in the list
function nexttask(proceed) {
  if (proceed && tasks.length) {
    // remove first task from list
    var task = tasks.slice(0,1);
    tasks = tasks.slice(1);

    // extract task name, add to the parameter list
    params.task = task.text();

    // add/move spinner to this task
    task.parent().append(spinner);

    // build fetch options
    options = {
      method: 'POST',
      headers: {'Content-Type': 'application/json'},
      body: JSON.stringify(params),
      credentials: 'include'
    }

    // perform fetch operation
    fetch('', options).then(function(response) {
      // display output
      response.json().then(function(json) {
        // remove all but the heading
        task.parent().empty().append(task);

        if (json.transcript) {
          var pre = $('<pre>');
          pre.text(json.transcript.join("\n"));

          // highlight commands
          pre.html(("\n" + pre.html()).replace(/\n(\$ \w+ .*)/g, 
            "\n<b>$1</b>").trim());

          // append results
          task.parent().append(pre);
        }

        if (json.message) {
          var pre = $('<pre class="bg-info">');
          pre.text(json.message);
          task.append(pre);
        }

        if (json.exception) {
          var pre = $('<pre class="bg-danger">');
          if (json.backtrace) {
            json.exception += "\n  " + json.backtrace.join("\n  ");
          }
          pre.text(json.exception);
          task.append(pre);
        }

        if (json.disposition) disposition = json.disposition;
        if (json.headers) headers = json.headers;

        // conditionally proceed to the next task
        nexttask(response.ok || 
          confirm(response.statusText + "; continue?"));
      });
    }).catch(function(error) {
      nexttask(confirm(error.message + "; continue?"));
    });

  } else { // done

    spinner.remove();

    if (!proceed) {
      $('h1').removeClass('bg-info').addClass('bg-danger').
        text('Processing Aborted');
      message = {status: 'aborted'};
      $('button#proceed').text('resume').prop('disabled', false);
    } else {
      $('h1').removeClass('bg-info').addClass('bg-success').
        text('Processing Complete');
      $('button#cancel').remove();
      $('button#proceed').html('return to<br>mail index').
        prop('disabled', false);
      message = {status: disposition || 'complete'};
    }

    if (headers) message.headers = headers;
    window.parent.frames[0].postMessage(message, '*')
  }
};

// start the process when the proceed button is clicked
$('button#proceed').on('click', function(event) {
  if (tasks.length) {
    $('h1').removeClass('bg-warning').addClass('bg-info').
      text('Request Status');
    $(this).prop('disabled', true);
    $('button#cancel').prop('disabled', true);
    nexttask(true);
  } else {
    window.parent.location.href = '..';
  }
});

// end the process when the cancel button is clicked
$('button#cancel').on('click', function(event) {
  $(this).prop('disabled', true);
  $('button#proceed').prop('disabled', true);
  message = {status: 'cancelled'};
  window.parent.frames[0].postMessage(message, '*');
  $('ul')[0].style.opacity = '0.5';
  $('h1').removeClass('bg-info').addClass('bg-danger').
    text('Operation cancelled');
});

// have delete and up keys return to index
$(document).on('keypress', function(event) {
  if (event.keyCode == 8 || event.keyCode == 46) { // backspace or delete
    var tag = event.target.tagName.toLowerCase();
    if (tag != 'input' && tag != 'textarea')  {
      window.parent.location.href = '..';
    }
  } else if (event.keyCode == 38) { // up
    window.parent.location.href = '..';
  }
});

// reenable form on exit of page
window.addEventListener('unload', function(){
  message = {status: 'exit'};
  window.parent.frames[0].postMessage(message, '*');
});
