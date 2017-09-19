

catch { array unset ::footer }

set ::footer(current) ""
proc heading {text tag {caption {}}} {
  set ::footer(current) $tag
  set ::footer(name,$tag) $text
}
proc doc {name url desc} {
  set name [string map [list "\n" " " "<br>" " "] $name]
  lappend ::footer(docs,$::footer(current)) $name $url
}

source [file join [file dirname [info script]] docsdata.tcl]

proc footer_list {tag} {
  set ret    "<div style=\"float:left\" id=docs_f$::footer(tcnt)>"
  append ret "<div class=doccat id=docs_$::footer(tcnt)>\n"
  append ret "<h><a href=docs.html#$tag>$::footer(name,$tag)</a>\n</h>"
  append ret "<ul>\n"
  foreach {name url} $::footer(docs,$tag) {
    append ret "<li> <a href=$url>$name</a>\n"
  }
  append ret "</ul>\n"
  append ret "</div>\n"
  append ret "</div>\n"

  incr ::footer(tcnt)
  return $ret
}

hd_puts "<div class=footer id=docs>"
hd_puts <h3>Resources</h3>

set ::footer(tcnt) 0
set ::footer(sections) {
  overview programming extensions
  features technical   advocacy
}

foreach f $::footer(sections) {
  hd_puts [footer_list $f]
}

hd_puts "<div class=footer style=\"clear:both\"></div>"

hd_puts [string map [list %NDOC% [llength $::footer(sections)]] {
  <script>

  function relayout_docs() {
    var nDoc = %NDOC%;
    var i;
    var j;

    for(i=0; i<nDoc; i++){
      var e = document.getElementById("docs_" + i);
      var f = document.getElementById("docs_f" + i);
      f.appendChild(e);
    }

    var sz = new Array;
    for(i=0; i<nDoc; i++){
      var ew = document.getElementById("docs_" + i).offsetWidth;
      sz[i] = ew;
    }
    sz.sort(function(a, b){return b-a;});

    var boxw = document.getElementById("docs").clientWidth;
    var w = boxw;
    var nCol;
    for(nCol=0; nCol<nDoc; nCol++){
      w -= sz[nCol];
      if( w<=0 ) break;
    }
    if( nCol<=0 ) nCol = 1;

    for(i=0; i<nCol; i++){
      var e = document.getElementById("docs_" + i);
      var f = document.getElementById("docs_f" + (i % nCol));
      f.appendChild(e);
      sz[i] = e.offsetHeight;
    }

    for(i=nCol ; i<nDoc; i++){
      var j;
      var iMin = 0;
      for(j=1; j<nCol; j++){
        if( sz[j]<sz[iMin] ){ iMin = j; }
      }
      var e = document.getElementById("docs_" + i);
      var f = document.getElementById("docs_f" + iMin);
      f.appendChild(e);
      sz[iMin] += e.offsetHeight;
    }


  }
  window.onresize = relayout_docs;
  relayout_docs();

  </script>
}]


