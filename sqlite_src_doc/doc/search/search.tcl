#!/usr/bin/tclsh.docsrc

source [file dirname [info script]]/document_header.tcl

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
proc attrize {str} { string map {< &lt; > &gt; \x22 &quot;} $str }

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

#-------------------------------------------------------------------------
# Add an entry to the log database for the current query. Which 
# returns $nRes results.
#
proc search_add_log_entry {nRes} {
  if {[info exists ::A(donotlog)]} return

  sqlite3 db2 search.d/searchlog.db
  db2 timeout 10000

  set ip $::env(REMOTE_ADDR)
  set query $::A(q)

  db2 eval {
    PRAGMA synchronous=OFF;
    PRAGMA journal_mode=OFF;
    BEGIN;
      CREATE TABLE IF NOT EXISTS log(
        ip,                  -- IP query was made from
        query,               -- Fts5 query string
        nres,                -- Number of results
        timestamp DEFAULT CURRENT_TIMESTAMP
      );
      INSERT INTO log(ip, query, nres) VALUES($ip, $query, $nRes);
    COMMIT;
  }

  db2 close
}

proc sqlize {text} {
  return "'[string map [list ' ''] $text]'"
}

proc admin_list {} {
  sqlite3 db2 searchlog.db

  set where ""
  set res ""

  set ipfilter ""
  if {[info exists ::A(ip)] && $::A(ip)!=""} {
    set where "WHERE ip = [sqlize $::A(ip)]"
    set ipfilter $::A(ip)
  }

  set checked ""
  if {[info exists ::A(unique)] && $::A(unique)} {
    set checked "checked"
  }

  set limit 10
  if {[info exists ::A(limit)]} {
    set limit $::A(limit)
  }
  set s10 ""
  set s100 ""
  set s1000 ""
  if {$limit==10} {set s10 selected}
  if {$limit==100} {set s100 selected}
  if {$limit==1000} {set s1000 selected}

  append res "
    <div style=\"margin:2em\">
    <center>
    <form action=admin method=get>
      Results: <select name=limit onChange=\"this.form.submit()\">
        <option $s10 value=\"10\">10</option>
        <option $s100 value=\"100\">100</option>
        <option $s1000 value=\"1000\">1000</option>
      </select>
      IP: <input type=input name=ip value=\"[attrize $ipfilter]\"> 
      Unique: <input 
        type=checkbox name=unique value=1 
        $checked
        onChange=\"this.form.submit()\"
      >
      <input type=submit>
    </form>
    </center>
    </div>
  "

  set i 0
  append res "<table border=1 cellpadding=10 align=center>\n"
  append res "<tr><td><th>IP <th>Query <th> Results <th> Timestamp\n"
  db2 eval "
    SELECT rowid, ip, query, nres, timestamp FROM log $where
    ORDER BY rowid DESC
  " {

    if {[info exists ::A(unique)] && $::A(unique)} {
      if {[info exists seen($query)]} continue
      set seen($query) 1
    }

    set querylink "<a href=\"../search?q=[attrize $query]&donotlog=1\">$query</a>"
    set iplink "<a href=\"?admin=1&ip=$ip\">$ip</a>"

    append res "  <tr> <td> $rowid <td> $iplink <td> $querylink"
    append res "       <td> $nres <td> $timestamp\n"

    incr i
    if {$i >= $limit} break
  }
  append res "</table>\n"

  return $res
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

proc searchchanges {} {
  global A
  if {![info exists A(q)]} return ""

  set open {<span style="background-color:#d9f2e6">}
  set close {</span>}
  set query {
    SELECT url, version, idx, highlight(change, 3, $open, $close) AS text 
    FROM change($A(q)) ORDER BY rowid ASC
  }

  set ret [subst {
    <p>Change log entries mentioning: <b>[htmlize $::A(q)]</b>
    <table border=0>
  }]

  set s2 "style=\"margin-top:0\""
  set s1 "style=\"font-size:larger; text-align:left\" class=nounderline"
  set prev ""
  db eval $query {
    if {$prev!=$version} {
      append ret [subst {
        <tr> <td $s1 valign=top> <a href=$url>$version</a> <td> <ul $s2>
      }]
      set prev $version
    }
    append ret [subst { <li value=$idx> ($idx) $text }]
  }

  append ret "</table>"
  append ret "<center><p>You can also see the <a href=changes.html>entire"
  append ret " changelog as a single page</a> if you wish.</center>"

  return $ret
}

proc searchresults {} {
  if {![info exists ::A(q)]} return ""
  #set ::A(q) [string map {' ''} $A(q)]
  #regsub -all {[^-/"A-Za-z0-9]} $::A(q) { } ::A(q)

  # Count the '"' characters in $::A(q). If there is an odd number of
  # occurences, add a " to the end of the query so that fts5 can parse
  # it without error.
  if {[regexp -all \x22 $::A(q)] % 2} { append ::A(q) \x22 }

  # Set iStart to the index of the first result to display. Results are
  # indexed starting at zero from most to least relevant.
  #
  set iStart [expr {([info exists ::A(i)] ? $::A(i) : 0)*10}]

  # Grab a list of rowid results.
  #
  set q {
    SELECT rowid FROM page WHERE page MATCH $::A(q) 
    ORDER BY srank(page) DESC,
    rank * COALESCE(
      (SELECT percent FROM weight WHERE id=page.rowid), 100
    );
  }
  if {[catch { set lRowid [db eval $q] }]} {
    set x ""
    foreach word [split $::A(q) " "] {
      append x " \"[string map [list "\"" "\"\""] $word]\""
    }
    set ::A(q) [string trim $x]
    set lRowid [db eval $q]
  }

  set lRes [list]
  foreach rowid $lRowid {
    if {$rowid > 1000} {
      set parent [expr $rowid / 1000]
      lappend subsections($parent) $rowid
    } else {
      lappend lRes $rowid
    }
  }

  set nRes [llength $lRes]
  set lRes [lrange $lRes $iStart [expr $iStart+9]]

  # Add an entry to the log database.
  #
  search_add_log_entry $nRes

  # If there are no results, return a message to that effect.
  #
  if {[llength $lRes] == 0} {
    return [subst { No results for: <b>[htmlize $::A(q)]</b> }]
  }
  
  # HTML markup used to highlight keywords within FTS5 generated snippets.
  #
  set open {<span style="background-color:#d9f2e6">}
  set close {</span>}
  set ellipsis {<b>&nbsp;...&nbsp;</b>}

  # Grab the required data
  #
  db eval [string map [list %LIST% [join $lRowid ,]] {
    SELECT 
      rowid AS parentid, 
      snippet(page, 0, $open, $close, $ellipsis, 6)  AS s_apis,
      snippet(page, 2, $open, $close, '', 40)        AS s_title1,
      snippet(page, 3, $open, $close, $ellipsis, 40) AS s_title2,
      snippet(page, 4, $open, $close, $ellipsis, 40) AS s_content,
      url, rank
    FROM page($::A(q))
    WHERE rowid IN (%LIST%)
  }] X {
    foreach k [array names X] { set data($X(parentid),$k) [set X($k)] }
  }

  set ret [subst {
    <table border=0>
    <p>Search results 
       [expr $iStart+1]..[expr {($nRes < $iStart+10) ? $nRes : $iStart+10}] 
       of $nRes for: <b>[htmlize $::A(q)]</b>
  }]

  foreach rowid $lRes {

    foreach a {parentid s_apis s_title1 s_content url rank} {
      set $a $data($rowid,$a)
    }

    if {[info exists subsections($parentid)]} {
      set childid [lindex $subsections($parentid) 0]
      set link $data($childid,url)
      set hdr $data($childid,s_title2)

      if {$hdr==""} {
        set s_content ""
      } else {
        set s_content [subst {
          <b><a style=color:#044a64 href=$link>$hdr</a></b>
        }]
      }

      append s_content " $data($childid,s_content)"
    }

    append ret [subst -nocommands {<tr>
      <td valign=top style="line-height:150%">
        <div style="white-space:wrap;font-size:larger" class=nounderline>
          <a href="$url">$s_title1 </a> 
          <div style="float:right;font-size:smaller;color:#BBB">($url)</div>
        </div>
          <div style="margin-left: 10ex; font:larger monospace">$s_apis</div>
        <div style="margin-left: 4ex; margin-bottom:1.5em">
           $s_content 
        </div>
      </td>
    }]
  }
  append ret { </table> }


  # If the query returned more than 10 results, add up to 10 links to 
  # each set of 10 results (first link to results 1-10, second to 11-20, 
  # third to 21-30, as required).
  #
  if {$nRes>10} {
    set s(0) {border:solid #044a64 1px;padding:1ex;margin:1ex;line-height:300%;}
    set s(1) "$s(0);background:#044a64;color:white"
    append ret <center><p>
    for {set i 0} {$i < 10 && ($i*10)<$nRes} {incr i} {
      append ret [subst {
        <a style="$s([expr {($iStart/10)==$i}])" 
           href="search?[cgi_encode_args [list q $::A(q) s $::A(s) i $i]]">[expr $i+1]</a>
      }]
    }
    append ret </center>
  }

  return $ret
}

proc main {} {
  global A
  cgi_parse_args

  # If "env=1" is specified, dump the environment variables instead
  # of running any search.
  if {[info exists ::A(env)]} { return [cgi_env_dump] }
  
  # If "admin=1" is specified, jump to the admin screen.
  if {[string match *admin* $::env(REQUEST_URI)]} {
    set ::PATH ../
    return [admin_list]
  }

  sqlite3 db search.d/search.db

  set cmd searchresults
  if {[info exists A(s)] && $A(s)=="c"} {
    set cmd searchchanges
  }

  db transaction {
    set t [ttime { 
      if {[catch $cmd srchout]} {
        set A(q) [string tolower $A(q)]
        set srchout [$cmd]
      }
      set doc $srchout
    }]
  }
  append doc "<center>"
  append doc "<p>Page generated by <a href='fts5.html'>FTS5</a> in about $t."
  append doc "</center>"
  return $doc

  # return [cgi_env_dump]
}

#=========================================================================

source [file dirname [info script]]/document_header.tcl

if {![info exists env(REQUEST_METHOD)]} {
  set env(REQUEST_METHOD) GET
  set env(QUERY_STRING) rebuild=1
  set ::HEADER ""

  #set env(QUERY_STRING) {q="one+two+three+four"+eleven}
  set env(QUERY_STRING) {q=windows}
  set ::HEADER ""
}

set ::PATH ""
if {0==[catch main res]} {
  set title "Search SQLite Documentation"
  if {[info exists ::A(q)]} {
    set initsearch [attrize $::A(q)]
    append title " - [htmlize $::A(q)]"
  } else {
    set initsearch {}
  }
  set document [document_header $title $::PATH $initsearch]
  append document [subst {
    <script>
      window.addEventListener('load', function() {
        var w = document.getElementById("searchmenu");
        w.style.display = "block";

        document.getElementById("searchtype").value = "$::A(s)"

        setTimeout(function(){
          var s = document.getElementById("searchbox");
          s.focus();
          s.select();
        }, 30);
      });
    </script>
  }]
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
