#!/usr/bin/tclsqlite4

#=========================================================================
# Decode an HTTP %-encoded string
#
proc percent_decode {str} {
    # rewrite "+" back to space
    # protect \ and [ and ] by quoting with '\'
    set str [string map [list + { } "\\" "\\\\" \[ \\\[ \] \\\]] $str]

    # prepare to process all %-escapes
    regsub -all -- {%([A-Fa-f][A-Fa-f0-9])%([A-Fa-f89][A-Fa-f0-9])} \
        $str {[encoding convertfrom utf-8 [binary decode hex \1\2]]} str
    regsub -all -- {%([0-7][A-Fa-f0-9])} $str {\\u00\1} str

    # process %-escapes
    return [subst -novar $str]
}

#=========================================================================
# This proc is called to parse the arguments passed to this invocation of
# the CGI program (via either the GET or POST method). It returns a
# key/value list containing the arguments suitable for passing to [array
# set]. For example, if the CGI is invoked via a GET request on the URI:
#
#   http://www.sqlite.org/search?query=fts3+table&results=10
#
# then the returned list value is: 
#
#   {query {fts3 table} results 10}
#
proc cgi_parse_args {} {
  global env A

  if {$env(REQUEST_METHOD) == "GET"} {
    foreach q [split $env(QUERY_STRING) &] {
      if {[regexp {([a-z0-9]*)=(.*)} $q all var value]} {
        set A($var) [percent_decode $value]
      }
    }
  } elseif {$env(REQUEST_METHOD) == "POST"} {
    set qstring [read stdin $env(CONTENT_LENGTH)]
    foreach q [split $qstring &] {
      if {[regexp {([a-z0-9]*)=(.*)} $q all var value]} {
        set A($var) [percent_decode $value]
      }
    }
  } else {
    error "Unrecognized method: $env(REQUEST_METHOD)"
  }
}


#=========================================================================
# Redirect the web-browser to URL $url. This command does not return.
#
proc cgi_redirect {url} {
  set server $::env(SERVER_NAME)
  set path [file dirname $::env(REQUEST_URI)]
  if {[string range $path end end]!="/"} {
    append path /
  }

  puts "Status: 302 Redirect"
  puts "Location: http://${server}${path}${url}"
  puts "Content-Length: 0"
  puts ""
  exit
}

#=========================================================================
# The argument contains a key value list. The values in the list are
# transformed to an HTTP query key value list. For example:
#
#   % cgi_encode_args {s "search string" t "search \"type\""}
#   s=search+string&t=search+%22type%22
#
proc cgi_encode_args {list} {
  set reslist [list]
  foreach {key value} $list {
    set value [string map {
      \x20 +   \x21 %21 \x2A %2A \x22 %22 \x27 %27 \x28 %28 \x29 %29 \x3B %3B 
      \x3A %3A \x40 %40 \x26 %26 \x3D %3D \x2B %2B \x24 %24 \x2C %2C \x2F %2F 
      \x3F %3F \x25 %25 \x23 %23 \x5B %5B \x5D %5D
    } $value]

    lappend reslist "$key=$value"
  }
  join $reslist &
}

proc htmlize {str} { string map {< &lt; > &gt;} $str }
proc attrize {str} { string map {< &lt; > &gt; \x22 \x5c\x22} $str }

#=========================================================================

proc cgi_env_dump {} {

  set ret "<h1>Arguments</h1><table>"
  foreach {key value} [array get ::A] {
    append ret "<tr><td>[htmlize $key]<td>[htmlize $value]"
  }
  append ret "</table>"

  append ret "<h1>Environment</h1><table>"
  foreach {key value} [array get ::env] {
    append ret "<tr><td>[htmlize $key]<td>[htmlize $value]"
  }
  append ret "</table>"
  return $ret
}

proc searchform {} {
  return {}
  set initial "Enter search term:"
  catch { set initial $::A(q) }
  return [subst {
    <table style="margin: 1em auto"> <tr><td>Search SQLite docs for:<td>
      <form name=f method=GET action=search4>
        <input name=q type=text width=35 value="[attrize $initial]"></input>
        <input name=s type=submit value="Search"></input>
        <input name=s type=submit value="Lucky"></input>
      </form>
    </table>
    <script> 
      document.forms.f.q.focus()
      document.forms.f.q.select()
    </script>
  }]
}

proc footer {} {
  return {
    <hr>
    <table align=right>
    <td>
      <i>Powered by <a href="http://www.sqlite.org/src4">FTS5</a>.</i>
    </table>
  }
}


#-------------------------------------------------------------------------
# This command is similar to the builtin Tcl [time] command, except that
# it only ever runs the supplied script once. Also, instead of returning
# a string like "xxx microseconds per iteration", it returns "x.yy ms" or
# "x.yy s", depending on the magnitude of the time spent running the 
# command. For example:
#
#   % ttime {after 1500}
#   1.50 s
#   % ttime {after 45}
#   45.02 ms
#
proc ttime {script} {
  set t [lindex [time [list uplevel $script]] 0]
  if {$t>1000000} { return [format "%.2f s" [expr {$t/1000000.0}]] }
  return [format "%.2f ms" [expr {$t/1000.0}]]
}

proc rank {matchinfo args} {
  binary scan $matchinfo i* I

  set nPhrase [lindex $I 0]
  set nCol [lindex $I 1]

  set G [lrange $I 2 [expr {1+$nCol*$nPhrase}]]
  set L [lrange $I [expr {2+$nCol*$nPhrase}] end]

  foreach a $args { lappend log [expr {log10(100+$a)}] }

  set score 0.0
  set i 0
  foreach l $L g $G {
    if {$l > 0} {
      set div [lindex $log [expr $i%3]]
      set score [expr {$score + (double($l) / double($g)) / $div}]
    }
    incr i
  }

  return $score
}
proc erank {matchinfo args} {
  eval rank [list $matchinfo] $args
}


proc searchresults {} {
  if {![info exists ::A(q)]} return ""
  #set ::A(q) [string map {' ''} $A(q)]
  #regsub -all {[^-/"A-Za-z0-9]} $::A(q) { } ::A(q)

  # Count the '"' characters in $::A(q). If there is an odd number of
  # occurences, add a " to the end of the query so that fts3 can parse
  # it without error.
  if {[regexp -all \x22 $::A(q)] % 2} { append ::A(q) \x22 }

  set ::TITLE "Results for: \"[htmlize $::A(q)]\""

  #db func rank rank
  #db func erank erank

  set score 0
  catch {set score $::A(score)}

  # Set nRes to the total number of documents that the users query matches.
  # If nRes is 0, then the users query returned zero results. Return a short 
  # message to that effect.
  #
  set nRes [db one { SELECT count(*) FROM pagedata WHERE pagedata MATCH $::A(q) }]
  if {$nRes == 0} {
    return [subst { No results for: <b>[htmlize $::A(q)]</b> }]
  }

  # Set iStart to the index of the first result to display. Results are
  # indexed starting at zero from most to least relevant.
  #
  set iStart [expr {([info exists ::A(i)] ? $::A(i) : 0)*10}]

  # HTML markup used to highlight keywords within FTS3 generated snippets.
  #
  set open {<span style="font-weight:bold; color:navy">}
  set close {</span>}
  set ellipsis {<b>&nbsp;...&nbsp;</b>}

  set ret [subst {
    <table border=0>
    <p>Search results 
       [expr $iStart+1]..[expr {($nRes < $iStart+10) ? $nRes : $iStart+10}] 
       of $nRes for: <b>[htmlize $::A(q)]</b>
  }]

  set open {<span style="font-weight:bold; color:navy">}
  set close {</span>}
  set ellipsis {<b>&nbsp;...&nbsp;</b>}

  if {0==[info exists ::A(e)]} {
    set sqlquery {
      SELECT url, title, 
      snippet(pagedata, $open, $close, $ellipsis, 3, 40) AS snippet,
      '' AS report
      FROM pagedata WHERE pagedata MATCH $::A(q)
      ORDER BY rankc(pagedata, 1.0, 5.0, 10.0, 1.0) DESC
      LIMIT 10 OFFSET $iStart
    }
  } else {
    set sqlquery {
      SELECT url, title, 
      snippet(pagedata, $open, $close, $ellipsis, 3, 40) AS snippet,
      erankc(pagedata, 1.0, 5.0, 10.0, 1.0) AS report
      FROM pagedata WHERE pagedata MATCH $::A(q)
      ORDER BY rankc(pagedata, 1.0, 5.0, 10.0, 1.0) DESC
      LIMIT 10 OFFSET $iStart
    }
  }

  set resnum $iStart
  db eval $sqlquery {
    incr resnum

    append ret [subst -nocommands {<tr>
      <td valign=top>${resnum}.</td>
      <td valign=top>
        <div style="white-space:wrap">
          <a href="$url">$title</a>
        </div>
        <div style="font-size:small;margin-left: 2ex">
          <div style="width:80ex"> $snippet </div>
          <div style="margin-bottom:1em"><a href="$url">$url</a></div>
        </div>
      </td>

      <td width=100%>
      <td valign=top style="font-size:70%;white-space:nowrap;color:darkgreen"> $report </td>
    }]
  }
  append ret { </table> }


  # If the query returned more than 10 results, add up to 10 links to 
  # each set of 10 results (first link to results 1-10, second to 11-20, 
  # third to 21-30, as required).
  #
  if {$nRes>10} {
    set s(0) {border: solid #044a64 1px ; padding: 1ex ; margin: 1ex}
    set s(1) "$s(0);background:#044a64;color:white"
    append ret <center><p>
    for {set i 0} {$i < 10 && ($i*10)<$nRes} {incr i} {
      append ret [subst {
        <a style="$s([expr {($iStart/10)==$i}])" 
           href="search4?[cgi_encode_args [list q $::A(q) i $i]]">[expr $i+1]</a>
      }]
    }
    append ret </center>
  }

  return $ret
}

proc main {} {
  global A
  sqlite4 db search4.db
  cgi_parse_args

  db transaction {
    set t [ttime { set doc "[searchform] [searchresults] [footer]" }]
  }
  append doc "<p>Page generated in $t."
  return $doc

  # return [cgi_env_dump]
}

#=========================================================================

set ::HEADER {
  <!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01//EN"
  "http://www.w3.org/TR/html4/strict.dtd">
  <html><head>
  <title>$TITLE</title>
  <style type="text/css">
  body {
    margin: auto;
    font-family: Verdana, sans-serif;
    padding: 8px 1%;
  }

  a { color: #044a64 }
  a:visited { color: #734559 }

  .logo { position:absolute; margin:3px; }
  .tagline {
    float:right;
    text-align:right;
    font-style:italic;
    width:300px;
    margin:12px;
    margin-top:58px;
  }
  .menubar {
    clear: both;
    border-radius: 8px;
    background: #044a64;
    padding: 0px;
    margin: 0px;
    cell-spacing: 0px;
  }
  .toolbar {
    text-align: center;
    line-height: 1.6em;
    margin: 0;
    padding: 0px 8px;
  }
  .toolbar a { color: white;
  text-decoration: none; padding: 6px
  12px; }
  .toolbar a:visited { color: white; }
  .toolbar a:hover { color: #044a64;
  background: white; }

  .content    { margin: 5%; }
  .content dt { font-weight:bold; }
  .content dd { margin-bottom: 25px; margin-left:20%; }
  .content ul { padding:0px; padding-left: 15px; margin:0px; }
  </style>
  <meta http-equiv="content-type" content="text/html; charset=UTF-8">
    
  </head>
  <body>
  <div><!-- container div to satisfy validator -->

  <a href="index.html">
  <img class="logo" src="images/sqlite370_banner.gif" alt="SQLite Logo" border="0"></a>
    <div><!-- IE hack to prevent disappearing logo--></div>
    <div class="tagline">Small. Fast. Reliable.<br>Choose any three.</div>

    <table width=100% class="menubar"><tr><td>
  <table width=100% style="padding:0;margin:0;cell-spacing:0"><tr>
  <td width=100%>
  <div class="toolbar">
    <a href="about.html">About</a>
    <a href="sitemap.html">Sitemap</a>
    <a href="docs.html">Documentation</a>
    <a href="download.html">Download</a>
    <a href="copyright.html">License</a>
    <a href="news.html">News</a>
    <a href="support.html">Support</a>
  </div>
<td>
    <div style="padding:0 1em 0px 0;white-space:nowrap">
    <form name=f method="GET" action="search4">
      <input id=q name=q type=text value=""
       onfocus="entersearch()" onblur="leavesearch()" style="width:24ex;padding:1px 1ex; border:solid white 1px; font-size:0.9em">
      <input type=submit value="Go" style="border:solid white 1px;background-color:#044a64;color:white;font-size:0.9em;padding:0 1ex">
    </form>
    </div>
  </table>
</div></div></div></div>
</td></tr></table>
  
<script>
  gMsg = "Search SQLite Docs..."
  function entersearch() {
    var q = document.getElementById("q");
    if( q.value == gMsg ) { q.value = "" }
    q.style.color = "black"
    q.style.fontStyle = "normal"
  }
  function leavesearch() {
    var q = document.getElementById("q");
    if( q.value == "" ) { 
      q.value = gMsg
      q.style.color = "#044a64"
      q.style.fontStyle = "italic"
    }
  }
  function initsearch() {
    var q = document.getElementById("q");
    q.value = ""
      q.value = $::INITSEARCH
      q.style.color = "black"
      q.style.fontStyle = "normal"
  }
  window.onload = initsearch
</script>
}

if {![info exists env(REQUEST_METHOD)]} {
  set env(REQUEST_METHOD) GET
  set env(QUERY_STRING) rebuild=1
  set ::HEADER ""

  set env(QUERY_STRING) {q=cache+size}
  set ::HEADER ""
}


set TITLE "Search SQLite Documentation (fts5)"

if {0==[catch main res]} {
  if {[info exists ::A(q)]} {
    set ::INITSEARCH \"[attrize $::A(q)]\"
  } else {
    set ::INITSEARCH \"\"
  }
  set document [subst -nocommands $::HEADER]
  append document $res
} else {
  set document "<pre>"
  append document "Error: $res\n\n"
  append document $::errorInfo
  append document "</pre>"
}

puts "Content-type: text/html" 
puts "Content-Length: [string length $document]"
puts ""
puts $document
puts ""
flush stdout
close stdout

exit
