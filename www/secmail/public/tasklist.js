var tasks = $('h3');
var spinner = $('<img src="../spinner.gif"/>')

function fake() {
  if (tasks.length) {
    tasks.first().parent().append(spinner);
    tasks = tasks.slice(1);
    setTimeout(fake, 2000);
  } else {
    spinner.remove();
    window.parent.frames[0].postMessage('hi', '*')
  }
}

$('button').click(function(event) {
  $(this).prop('disabled', true);
  fake();
});

