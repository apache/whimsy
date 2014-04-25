function reflow(element) {
  text = element.val();

  // join consecutive lines (making exception for <markers> like <private>)
  text = text.replace(/([^\s>])\n(\w)/g, '$1 $2');

  // reflow each line
  lines = text.split("\n");
  for (var i=0; i<lines.length; i++) {

    var indent = lines[i].match(/( *)(.?.?)(.*)/m);
    if (indent[1] == '' || indent[3] == '') {
      // not indented (or short) -> split
      lines[i] = lines[i].
        replace(/(.{1,78})( +|$\n?)|(.{1,78})/g, "$1$3\n").
        replace(/[\n\r]+$/, '');
    } else {
      // preserve indentation.  indent[2] is the 'bullet' (if any) and is
      // only to be placed on the first line.
      var n = 76 - indent[1].length;
      var regexp =
        new RegExp("(.{1,"+n+"})( +|$\n?)|(.{1,"+n+"})", 'g');
      lines[i] = indent[3].
        replace(regexp, indent[1] + "  $1$3\n").
        replace(indent[1] + '  ', indent[1] + indent[2]).
        replace(/[\n\r]+$/, '');
    }
  }

  element.val(lines.join("\n"));
}


RegExp.new("(.{1,#{n}})( +|$\n?)|(.{1,#{n}})", 'g')
