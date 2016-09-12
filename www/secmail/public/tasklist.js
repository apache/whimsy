var tasks = $('h3');
var spinner = $('<img src="../spinner.gif"/>');

// Load fetch shim, if needed (e.g., by Safari)
if (typeof fetch === 'undefined') {
  var script = document.createElement('script');
  script.type = 'text/javascript';
  script.src = 'public/fetch.js';
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
        if (json.transcript) {
          var pre = $('<pre>');
          pre.text(json.transcript.join("\n"));

          // highlight commands
          pre.html(("\n" + pre.html()).replace(/\n(\$ \w+ .*)/g, 
            "\n<b>$1</b>").trim());

          task.append(pre);
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
      });

      // conditionally proceed to the next task
      nexttask(response.ok || confirm(response.statusText + "; continue?"));
    }).catch(function(error) {
      nexttask(confirm(error.message + "; continue?"));
    });

  } else { // done

    spinner.remove();

    if (tasks.length) {
      $('h1').removeClass('bg-info').addClass('bg-danger').
        text('Processing Aborted');
      message = {status: 'aborted'}
    } else {
      $('h1').removeClass('bg-info').addClass('bg-success').
        text('Processing Complete');
      message = {status: 'complete'}
    }

    window.parent.frames[0].postMessage(message, '*')
  }
};

$('button').click(function(event) {
  $('h1').removeClass('bg-warning').addClass('bg-info').
    text('Request Status');
  $(this).prop('disabled', true);
  nexttask(true);
});

