// prime the second frame
if (parent.frames[1].location == 'about:blank') {
  parent.frames[1].location.href = "file.cgi?action=update"
}

// Map non-ASCII characters to lower case ASCII
function asciize(name) {
  if (name.match(/[^\x00-\x7F]/)) {
    // digraphs.  May be culturally sensitive
    name=name.replace(/\u00df/g,'ss');
    name=name.replace(/\u00e4|a\u0308/g,'ae');
    name=name.replace(/\u00e5|a\u030a/g,'aa');
    name=name.replace(/\u00e6/g,'ae');
    name=name.replace(/\u00f1|n\u0303/g,'ny');
    name=name.replace(/\u00f6|o\u0308/g,'oe');
    name=name.replace(/\u00fc|u\u0308/g,'ue');

    // latin 1
    name=name.replace(/[\u00e0-\u00e5]/g,'a');
    name=name.replace(/\u00e7/g,'c');
    name=name.replace(/[\u00e8-\u00eb]/g,'e');
    name=name.replace(/[\u00ec-\u00ef]/g,'i');
    name=name.replace(/[\u00f2-\u00f6]|\u00f8/g,'o');
    name=name.replace(/[\u00f9-\u00fc]/g,'u');
    name=name.replace(/[\u00fd\u00ff]/g,'y');

    // Latin Extended-A
    name=name.replace(/[\u0100-\u0105]/g,'a');
    name=name.replace(/[\u0106-\u010d]/g,'c');
    name=name.replace(/[\u010e-\u0111]/g,'d');
    name=name.replace(/[\u0112-\u011b]/g,'e');
    name=name.replace(/[\u011c-\u0123]/g,'g');
    name=name.replace(/[\u0124-\u0127]/g,'h');
    name=name.replace(/[\u0128-\u0131]/g,'i');
    name=name.replace(/[\u0132-\u0133]/g,'ij');
    name=name.replace(/[\u0134-\u0135]/g,'j');
    name=name.replace(/[\u0136-\u0138]/g,'k');
    name=name.replace(/[\u0139-\u0142]/g,'l');
    name=name.replace(/[\u0143-\u014b]/g,'n');
    name=name.replace(/[\u014C-\u0151]/g,'o');
    name=name.replace(/[\u0152-\u0153]/g,'oe');
    name=name.replace(/[\u0154-\u0159]/g,'r');
    name=name.replace(/[\u015a-\u0162]/g,'s');
    name=name.replace(/[\u0162-\u0167]/g,'t');
    name=name.replace(/[\u0168-\u0173]/g,'u');
    name=name.replace(/[\u0174-\u0175]/g,'w');
    name=name.replace(/[\u0176-\u0178]/g,'y');
    name=name.replace(/[\u0179-\u017e]/g,'z');

    // denormalized diacritics
    name=name.replace(/[\u0300-\u036f]/g,'');
  }

  return name.replace(/[^\w]+/g,'-');
}

// Generate file name from real name (icla)
function generateFileName(selection) {
  var value = asciize($('#realname').val());
  var source = $('#source').val();
  if (source.indexOf('.')>0) {
    if (source.indexOf('@')<0 || source.match(/\.pdf$/)) {
      value+=source.replace(/.*\./,'.');
    }
  }
  return value.replace(/-+/g, '-').toLowerCase();
}

$(document).ready(function() {
  // member autofill
  $('#mavailid').change(function() {
    var selected = $('#mavailid :selected'); 
    if (!$('#memail').val()) $("#memail").val($(this).val()+"@apache.org");
    $("#email").val($(this).val()+"@apache.org");
    $("#mfname").val(selected.text());
    $("#realname").val(selected.text());
    $("#mfilename").val(generateFileName());
    $("#maddr").focus();
  });

  // File selection
  $('#worklist a').click(function() {
    var link = $(this).text();
    var directory = link.match("/$");
    $("*[id$='-form']").hide();
    $("#buttons").hide();
    $("#buckets").hide();
    $("#doctype")[0].reset();
    $("#classify").show();
    $("#source").val(link);

    $("li:has(a)").removeClass('selected');
    if (directory) {
      $("li:has(a:contains('" + link + "/'))").addClass('selected');
    } else {
      $("li:has(a:contains('" + link + "'))").addClass('selected');
    }

    if (directory || link.match(/pgp\.txt$/)) {
      parent.frames[1].location.href = 'file.cgi?action=view&dir=' +
        encodeURIComponent(link);
    } else {
      parent.frames[1].location.href = '/members/received/' + link;
    }

    if (!link.match(/^eFax-\d+\.pdf$/)) {
      $("#icla-form input").addClass("loading");
      $("#ccla-form input").addClass("loading");
      $("#grant-form input").addClass("loading");
      $.post('file.cgi', {cmd: 'svninfo', source: link}, function(info) {
        if (!$('#realname').val()) $('#realname').val(info.from);
        if (!$('#nname').val())    $('#nname').val(info.from);
        if (!$('#contact').val())  $('#contact').val(info.from);
        if (!$('#gname').val())    $('#gname').val(info.from);
        if (!$('#email').val())    $('#email').val(info.email);
        if (!$('#cemail').val())   $('#cemail').val(info.email);
        if (!$('#gemail').val())   $('#gemail').val(info.email);
        if (!$('#nemail').val())   $('#nemail').val(info.email);
        if (!$('#memail').val())   $('#memail').val(info.email);
        if (!$('#nid').val()) {
          var email = $('#email').val();
          if (email.match(/^\w+@apache.org$/)) {
            $('#nid').val(email.split('@')[0]);
          }
        }
        $("#icla-form input").removeClass("loading");
        $("#ccla-form input").removeClass("loading");
        $("#grant-form input").removeClass("loading");
      }, 'json');
    }
  });

  // Classification
  $('#doctype input[name=doctype]').click(function() {
    var selection = $(this).attr('value');
    $("*[id$='-form']").slideUp();
    $("#"+selection+"-form").slideDown();
    $("#"+selection+"2-form").slideDown();
    if (selection == 'other') {
      $("#buckets").show();
      $("#buttons").hide();
    } else {
      $("#buckets").hide();
      $("#buttons").show();
    }
    $("#replaces").val("");
    if (selection == 'icla') {
      $("#archive").removeAttr("disabled");
    } else {
      $("#archive").attr("disabled", "disabled");
    }
  });

  // Fill in
  $("#pubname").focus(function() {
    if (this.value=='') this.value=$('#realname').val();
  });

  $("#email").focus(function() {
    if (this.value=='') {
      var source = $('#source').val();
      if (source.indexOf('@') == -1) source='';
      this.value = source.toLowerCase();
    }
  });

  $("#filename, #nfilename").focus(function() {
    if (this.value=='') this.value = generateFileName();
  });

  $("input[name=cfilename]").focus(function() {
    if (this.value=='') {
      var source = $('#source').val();
      var value = $('#company').val();
      var product = $('#product').val();
      if (product) value += '-' + product;
      value = asciize(value);
      if (source.indexOf('.')>0) {
        if (source.indexOf('@')<0 || source.match(/\.pdf$/)) {
          value+=source.replace(/.*\./,'.');
        }
      }
      value = value.replace(/-+/g,'-').toLowerCase();
      value = value.replace(/-[.]/,'.');
      value = value.replace(/-inc[.]/,'.');
      this.value = value;
    }
  });

  $("#nemail").focus(function() {
    if (this.value=='') this.value=$('#nid').val()+'@apache.org';
  });

  // Commit prompt
  $("input[value=Commit]").click(function() {
    var message = prompt("Commit Message?", $('#message').attr('data-value'));
    if (message) {
      $('#message').attr('value', message);
      return true;
    } else {
      return false;
    }
  });
});
