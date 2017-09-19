#!/usr/bin/tclsh
#
# This script generates the requirements traceability matrix and does
# other processing related to requirements and coverage analysis.
#

# Get a list of source HTML files.
#
set filelist [lsort [glob -nocomplain doc/*.html doc/c3ref/*.html doc/syntax/*.html]]
foreach exclude {doc/capi3ref.html doc/changes.html} {
  set i [lsearch $filelist $exclude]
  set filelist [lreplace $filelist $i $i]
}

# Initialize the database connection.
#
sqlite3 db docinfo.db
db eval {
  ATTACH 'history.db' AS history;
  CREATE TABLE IF NOT EXISTS history.allreq(
    reqno TEXT PRIMARY KEY,  -- Ex: R-12345-67890-...
    reqimage BOOLEAN,        -- True for an image requirement
    reqtext TEXT,            -- Normalized text of requirement or image filename
    srcfile TEXT             -- Document from which extracted
  );
  BEGIN;
  DELETE FROM requirement;
  DELETE FROM reqsrc;
}

# Extract requirement text from all of the HTML files in $filelist
#
# Requirements text is text between "^" and "." or between "^(" and ")^".
# Requirement text is normalized by removing all HTML markup, removing
# all whitespace from the beginning and end, and converting all internal
# whitespace sequences into a single space character.
#
# Syntax diagrams are considered their own requirement if they are
# embedded using markup of the following patter:
#
#    <img alt="syntax diagram NAME" src="FILENAME.gif">
#
# The requirement table of the docinfo.db is populated with requirement
# information.  See the schema.tcl source file for a definition of the
# requirment table.
#
puts -nonewline "Scanning documentation for testable statements"
flush stdout
foreach file $filelist {
  if {$file=="doc/fileformat.html" 
        && [lsearch $filelist doc/fileformat2.html]>=0} {
    continue
  }
  puts -nonewline .
  # puts "$file..."
  flush stdout
  set in [open $file]
  set x [read $in [file size $file]]
  close $in
  set orig_x $x
  set origlen [string length $x]
  regsub {^doc/} $file {} srcfile
  set seqno 0
  while {[string length $x]>0 && [regsub {^.*?\^} $x {} nx]} {
    set c [string index $nx 0]
    set seqno [expr {$origlen - [string length $nx]}]
    set req {}
    if {$c=="("} {
      regexp {^\((([^<]|<.+?>)*?)\)\^} $nx all req
      regsub {^\((([^<]|<.+?>)*?)\)\^} $nx {} nx
    } else {
      regexp {^([^<]|<.+?>)*?\.} $nx req
      regsub {^([^<]|<.+?>)*?\.} $nx {} nx
    }
    if {$req==""} {
      puts "$srcfile: bad requirement: [string range $nx 0 40]..."
      set x $nx
      continue
    }
    set orig [string trim $req]
    regsub -all {<.+?>} $orig {} req
    regsub -all {\s+} [string trim $req] { } req
    set req [string map {&lt; < &gt; > &#91; [ &#93; ] &amp; &} $req]
    set req [string trim $req]
    set reqno R-[md5-10x8 $req]
    db eval {SELECT srcfile AS s2, reqtext as r2
             FROM requirement WHERE reqno=$reqno} {
      puts "$srcfile: duplicate [string range $reqno 0 12] in $s2: \[$r2\]"
    }
    db eval {
      INSERT OR IGNORE INTO requirement
              (reqno, reqtext, origtext, reqimage,srcfile,srcseq)
        VALUES($reqno,$req,    $orig,    0,      $srcfile,$seqno);
    }
    db eval {
      INSERT OR IGNORE INTO reqsrc(srcfile, srcseq, reqno)
      VALUES($srcfile, $seqno, $reqno)
    }
    db eval {
      INSERT OR IGNORE INTO allreq(reqno,reqimage,reqtext,srcfile)
        VALUES($reqno,0,$req,$srcfile);
    }
    set x $nx
  }
  set x $orig_x
  unset orig_x
  while {[string length $x]>0 
     && [regexp {^(.+?)(<img alt="syntax diagram .*)$} $x all prefix suffix]} {
    set x $suffix
    set seqno [expr {$origlen - [string length $x]}]
    if {[regexp \
           {<img alt="(syntax diagram [-a-z]+)" src="[./]*([-./a-z]+\.gif)"} \
           $x all name image]} {
      #puts "DIAGRAM: $file $name $image $seqno"
      set req $name
      set orig "<img src=\"$image\">"
      if {![file exists doc/$image]} {
        puts stderr "No such image: doc/$image"
        continue
      }
      set reqno R-[md5file-10x8 doc/$image]

      if {[string match *syntax/*.html $srcfile]} {
        db eval {DELETE FROM requirement WHERE reqno=$reqno}
      }
      db eval {
        INSERT OR IGNORE INTO requirement
                (reqno, reqtext, origtext, reqimage,srcfile,srcseq)
          VALUES($reqno,$req,    $orig,    1,      $srcfile,$seqno);
      }
      db eval {
        INSERT OR IGNORE INTO reqsrc(srcfile, srcseq, reqno)
        VALUES($srcfile,$seqno,$reqno)
      }
      db eval {
        INSERT OR IGNORE INTO allreq(reqno, reqimage, reqtext, srcfile)
          VALUES($reqno,1,$req,$srcfile);
      }
    }
  }
}
db eval COMMIT
set cnt [db one {SELECT count(*) FROM requirement}]
set evcnt [db one {
  SELECT count(*) FROM requirement WHERE reqno IN (SELECT reqno FROM evidence)
}]
set evpct [format {%.1f%%} [expr {$evcnt*100.0/$cnt}]]
puts "\nFound $cnt testable statements. Evidence exists for $evcnt or $evpct"

# Report all evidence for which there is no corresponding requirement.
# Such evidence is probably "stale" - the requirement text has changed but
# the evidence text did not.
#
db eval {
  SELECT reqno, srcfile, srcline FROM evidence
   WHERE reqno NOT IN (SELECT reqno FROM requirement)
} {
  puts "ERROR: stale evidence at $srcfile:$srcline - $reqno"
  db eval {SELECT reqtext, srcfile AS srcx FROM allreq WHERE reqno GLOB ($reqno||'*')} {
    puts "... in $srcx: \"$reqtext\""
  }
}


########################################################################
# Header output routine adapted from wrap.tcl.  Keep the two in sync.
#
# hd_putsin4 is like puts except that it removes the first 4 indentation
# characters from each line.  It also does variable substitution in
# the namespace of its calling procedure.
#
proc putsin4 {fd text} {
  regsub -all "\n    " $text \n text
  puts $fd [uplevel 1 [list subst -noback -nocom $text]]
}

# A procedure to write the common header found on every HTML file on
# the SQLite website.
#
proc write_header {path fd title} {
  puts $fd {<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01//EN" "http://www.w3.org/TR/html4/strict.dtd">}
  puts $fd {<html><head>}
  puts $fd "<title>$title</title>"
  putsin4 $fd {<style type="text/css">
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
      width:240px;
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
    .toolbar a { color: white; text-decoration: none; padding: 6px 12px; }
    .toolbar a:visited { color: white; }
    .toolbar a:hover { color: #044a64; background: white; }
    
    .content    { margin: 5%; }
    .content dt { font-weight:bold; }
    .content dd { margin-bottom: 25px; margin-left:20%; }
    .content ul { padding:0px; padding-left: 15px; margin:0px; }

    /* Text within colored boxes.
    **  everr is red.  evok is green. evnil is white */
    .everr {
      font-family: monospace;
      font-style: normal;
      background: #ffa0a0;
      border-style: solid;
      border-width: 2px;
      border-color: #a00000;
      padding: 0px 5px 0px 5px;
    }
    .evok {
      font-family: monospace;
      font-style: normal;
      background: #a0ffa0;
      border-style: solid;
      border-width: 2px;
      border-color: #00a000;
      padding: 0px 5px 0px 5px;
    }
    .evl0 {
      font-family: monospace;
      font-style: normal;
      background: #ffffff;
      border-style: solid;
      border-width: 2px;
      border-color: #0060c0;
      padding: 0px 5px 0px 5px;
    }
    .evl1 {
      font-family: monospace;
      font-style: normal;
      background: #c0f0ff;
      border-style: solid;
      border-width: 2px;
      border-color: #0060c0;
      padding: 0px 5px 0px 5px;
    }
    .evl2 {
      font-family: monospace;
      font-style: normal;
      background: #90c7fe;
      border-style: solid;
      border-width: 2px;
      border-color: #0060c0;
      padding: 0px 5px 0px 5px;
    }
    .evl3 {
      font-family: monospace;
      font-style: normal;
      background: #40a0ff;
      border-style: solid;
      border-width: 2px;
      border-color: #0060c0;
      padding: 0px 5px 0px 5px;
    }
    .evnil {
      font-family: monospace;
      font-style: normal;
      border-style: solid;
      border-width: 1px;
      padding: 0px 5px 0px 5px;
    }
    .ev {
      font-family: monospace;
      padding: 0px 5px 0px 5px;
    }
    

    </style>
    <meta http-equiv="content-type" content="text/html; charset=UTF-8">
  }
  puts $fd {</head>}
  if {[file exists DRAFT]} {
    set tagline {<font size="6" color="red">*** DRAFT ***</font>}
  } else {
    set tagline {Small. Fast. Reliable.<br>Choose any three.}
  }
  putsin4 $fd {<body>
    <div><!-- container div to satisfy validator -->
    
    <a href="${path}index.html">
    <img class="logo" src="${path}images/sqlite370_banner.gif" alt="SQLite Logo"
     border="0"></a>
    <div><!-- IE hack to prevent disappearing logo--></div>
    <div class="tagline">${tagline}</div>

    <table width=100% class="menubar"><tr><td>
      <div class="toolbar">
        <a href="${path}about.html">About</a>
        <a href="${path}docs.html">Documentation</a>
        <a href="${path}download.html">Download</a>
        <a href="${path}copyright.html">License</a>
        <a href="${path}support.html">Support</a>
        <a href="http://www.hwaci.com/sw/sqlite/prosupport.html">Purchase</a>
      </div>
    </td></tr></table>
  }
}
# End of code copied out of wrap.tcl
##############################################################################

# Generate the requirements traceability matrix.
#
puts "Generating requirements matrix..."
flush stdout
set out [open doc/matrix/matrix.html w]
write_header ../ $out {SQLite Requirements Matrix Index}
puts $out "<h1 align=center>SQLite Requirements Matrix Index</h1>"
puts $out "<table border=0 align=center>"
set srclist [db eval {SELECT DISTINCT srcfile FROM requirement ORDER BY 1}]
set rowcnt 0
set column_titles {<tr><th><th>tcl<th>slt<th>th3<th>src<th>any<th><th></tr>}
set total(tcl) 0
set total(th3) 0
set total(src) 0
set total(slt) 0
set total(any) 0
set total(all) 0

foreach srcfile $srclist {
  if {$rowcnt%20==0} {puts $out $column_titles}
  incr rowcnt
  db eval {
    CREATE TEMP TABLE IF NOT EXISTS srcreq(reqno TEXT PRIMARY KEY ON CONFLICT IGNORE);
    DELETE FROM srcreq;
    INSERT INTO srcreq SELECT reqno FROM requirement WHERE srcfile=$srcfile;
  }
  set totalcnt [db one {SELECT count(*) FROM srcreq}]
  incr total(all) $totalcnt
  puts $out "<tr><td><a href=\"$srcfile\">$srcfile</a></td>"
  set ev(tcl) 0
  set ev(th3) 0
  set ev(src) 0
  set ev(slt) 0
  set ev(any) 0
  db eval {
    SELECT count(distinct reqno) AS cnt, srcclass 
      FROM evidence
     WHERE reqno IN srcreq
     GROUP BY srcclass
  } {
    set ev($srcclass) $cnt
    incr total($srcclass) $cnt
  }
  db eval {
    SELECT count(distinct reqno) AS cnt
      FROM evidence
     WHERE reqno IN srcreq
  } {
    set ev(any) $cnt
    incr total(any) $cnt
  }
  foreach srcclass {tcl slt th3 src any} {
    set cnt $ev($srcclass)
    if {$cnt==$totalcnt} {
      set cx evok
    } elseif {$cnt>=0.75*$totalcnt} {
      set cx evl3
    } elseif {$cnt>=0.5*$totalcnt} {
      set cx evl2
    } elseif {$cnt>=0.25*$totalcnt} {
      set cx evl1
    } elseif {$cnt>0} {
      set cx evl0
    } else {
      set cx evnil
    }
    set amt [format {%3d/%-3d} $cnt $totalcnt]
    set amt [string map {{ } {&nbsp;}} $amt]
    puts $out "<td><cite class=$cx>$amt</cite></td>"
  }
  regsub -all {[^a-zA-Z0-9]} [file tail [file root $srcfile]] _ docid
  puts $out "<td><a href=\"matrix_s$docid.html\">summary</a></td>"
  puts $out "<td><a href=\"matrix_d$docid.html\">details</a></td></tr>\n"
}
if {$rowcnt%20!=1} {puts $out $column_titles}
puts $out "<tr><td>Overall Coverage"
set totalcnt $total(all)
foreach srcclass {tcl slt th3 src any} {
  set cnt $total($srcclass)
  if {$cnt==$totalcnt} {
    set cx evok
  } elseif {$cnt>=0.75*$totalcnt} {
    set cx evl3
  } elseif {$cnt>=0.5*$totalcnt} {
    set cx evl2
  } elseif {$cnt>=0.25*$totalcnt} {
    set cx evl1
  } elseif {$cnt>0} {
    set cx evl0
  } else {
    set cx evnil
  }
  set amt [format {%5.1f%% } [expr {($cnt*100.0)/$totalcnt}]]
  set amt [string map {{ } {&nbsp;}} $amt]
  puts $out "<td><cite class=$cx>$amt</cite></td>"
}
puts $out </table>
close $out

# Split a long string of text at spaces so that no line exceeds 70
# characters.  Send the result to $out.
#
proc wrap_in_comment {out prefix txt} {
  while {[string length $txt]>70} {
    set break [string last { } $txt 70]
    if {$break == 0} {
      set break [string first { } $txt]
    }
    if {$break>0} {
      puts $out "$prefix [string range $txt 0 [expr {$break-1}]]"
      set txt [string trim [string range $txt $break end]]
    } else {
      puts $out "$prefix $txt"
      return
    }
  }
  puts $out "$prefix $txt"
}



# Detail matrixes for each document.
#
foreach srcfile $srclist {
  regsub -all {[^a-zA-Z0-9]} [file tail [file root $srcfile]] _ docid
  set fn matrix_d$docid.html
  set matrixname($srcfile) $fn
  set out [open doc/matrix/$fn w]
  regsub {^doc/} $srcfile {} basename
  write_header ../ $out "SQLite Requirement Matrix: [file tail $srcfile]"
  puts $out "<h1 align=center>SQLite Requirement Matrix Details<br>"
  puts $out "[file tail $srcfile]</h1>"
  puts $out "<h2><a href=\"matrix.html\">Index</a>"
  puts $out "<a href=\"matrix_s$docid.html\">Summary</a>"
  puts $out "<a href=\"$basename\">Markup</a>"
  puts $out "<a href=\"../$basename\">Original</a></h2>"

  db eval {
    SELECT requirement.reqno, reqimage, origtext, reqtext,
           CASE WHEN requirement.srcfile!=$srcfile THEN requirement.srcfile END AS canonical
      FROM requirement, reqsrc
     WHERE reqsrc.srcfile=$srcfile
       AND reqsrc.reqno=requirement.reqno
     ORDER BY reqsrc.srcseq
  } {
    puts $out "<hr><a name=\"$reqno\"></a>"
    puts $out "<p><a href=\"$basename#$reqno\">$reqno</a>"

    set ev(tcl) 0
    set ev(slt) 0
    set ev(th3) 0
    set ev(src) 0
    db eval {
      SELECT count(*) AS cnt, srcclass 
        FROM evidence
       WHERE reqno=$reqno
       GROUP BY srcclass
    } {
      set ev($srcclass) $cnt
    }
    set proof($reqno) 0
    foreach srcclass {tcl slt th3 src} {
      set cnt $ev($srcclass)
      if {$cnt} {
        set cx evok
        incr proof($reqno)
      } else {
        set cx evnil
      }
      puts $out "<cite class=$cx>$srcclass</cite>"
    }
    puts $out "</p>"
    if {$canonical!=""} {
      puts $out "<p>Canonical usage: <a href='$canonical'>$canonical</a></p>"
    }
    set orig [string map -nocase {<dt> {} </dt> {} <dd> {} </dd> {}} $origtext]
    puts $out "<p>$orig</p>"
    set sep <p>

    db eval {
      SELECT srccat || '/' || srcfile || ':' || srcline AS x, url
        FROM evidence
       WHERE reqno=$reqno
       ORDER BY x;
    } {
      if {$url!=""} {
        puts $out "$sep<a href=\"$url\">$x</a>"
      } else {
        puts $out "$sep$x"
      }
      set sep "&nbsp;&nbsp;"
    }

    # Generate text suitable for copy-paste into source documents as
    # evidence that the requirement is satisfied.
    #
    set abbrev [string range $reqno 0 12]
    puts $out "<pre>/* IMP: $abbrev */</pre>"
    if {[regexp {^syntax diagram } $reqtext]} {
      puts $out "<pre># EVIDENCE-OF: $abbrev -- $reqtext</pre>"
    } else {
      puts $out "<pre>"
      wrap_in_comment $out # \
         "EVIDENCE-OF: $abbrev [string map {& &amp; < &lt; > &gt;} $reqtext]"
      puts $out "</pre>"
    }

  }
  close $out
}

# Summary matrixes for each document.
#
foreach srcfile $srclist {
  set has_req($srcfile) 1
  regsub -all {[^a-zA-Z0-9]} [file tail [file root $srcfile]] _ docid
  set fn matrix_s$docid.html
  set out [open doc/matrix/$fn w]
  regsub {^doc/} $srcfile {} basename
  write_header ../ $out "SQLite Requirement Matrix: [file tail $srcfile]"
  puts $out "<h1 align=center>SQLite Requirement Matrix Summary<br>"
  puts $out "[file tail $srcfile]</h1>"
  puts $out "<h2 align=center><a href=\"matrix.html\">Index</a>"
  puts $out "<a href=\"matrix_d$docid.html\">Details</a></h2>"
  puts $out {<table align=center>}

  db eval {
    SELECT reqno, reqimage, origtext
      FROM requirement
     WHERE srcfile=$srcfile
     ORDER BY srcseq
  } {
    puts $out "<tr><td><a class=ev href=\"$basename#$reqno\">$reqno</a></td>"

    set ev(tcl) 0
    set ev(slt) 0
    set ev(th3) 0
    set ev(src) 0
    db eval {
      SELECT count(*) AS cnt, srcclass 
        FROM evidence
       WHERE reqno=$reqno
       GROUP BY srcclass
    } {
      set ev($srcclass) $cnt
    }
    set proof($reqno) 0
    foreach srcclass {tcl slt th3 src} {
      set cnt $ev($srcclass)
      if {$cnt} {
        set cx evok
        incr proof($reqno)
      } else {
        set cx evnil
      }
      puts $out "<td><cite class=$cx>$srcclass</cite></td>"
    }
    puts $out "</td>"
  }
  puts $out {</table>}
  close $out
}

# Translate documentation to show requirements with links to the matrix.
#
puts -nonewline "Translating documentation"
flush stdout
foreach file $filelist {
  puts -nonewline .
  # puts $file
  flush stdout
  regsub {^doc/} $file {} basename
  set outfile doc/matrix/$basename
  if {![info exists matrixname($basename)]} {
    file copy -force $file $outfile
    continue
  }
  set in [open $file]
  set x [read $in [file size $file]]
  close $in
  if {[regexp / $basename]} {
    set matrixpath ../$matrixname($basename)
  } else {
    set matrixpath $matrixname($basename)
  }
  set out {}
  while {[string length $x]>0 && [set n [string first ^ $x]]>=0} {
    incr n -1
    set prefix [string range $x 0 $n]
    append out $prefix
    set n [string length $prefix]
    set nx [string range $x [expr {$n+1}] end]
    set c [string index $nx 0]
    if {$c=="("} {
      regexp {^\((([^<]|<.+?>)*?)\)\^} $nx all req
      regsub {^\((([^<]|<.+?>)*?)\)\^} $nx {} nx
    } else {
      regexp {^([^<]|<.+?>)*?\.} $nx req
      regsub {^([^<]|<.+?>)*?\.} $nx {} nx
    }
    set orig [string trim $req]
    regsub -all {<.+?>} $orig {} req
    regsub -all {\s+} [string trim $req] { } req
    set req [string map {&lt; < &gt; > &#91; [ &#93; ] &amp; &} $req]
    set req [string trim $req]
    set rno R-[md5-10x8 $req]
    set shortrno [string range $rno 0 12]
    append out "<a name=\"$rno\"></a><font color=\"blue\"><b>\n"
    set link "<a href=\"$matrixpath#$rno\" style=\"color: #0000ff\">"
    append out "$link$shortrno</a>:\[</b></font>"
    if {![info exists proof($rno)]} {
      set clr red
    } elseif {$proof($rno)>=2} {
      set clr green
    } elseif {$proof($rno)==1} {
      set clr orange
    } else {
      set clr red
    }
    append out "<font color=\"$clr\">$orig</font>\n"
    append out "<font color=\"blue\"><b>\]</b></font>\n"
    set x $nx
  }
  append out $x
  set x $out
  set out {}
  while {[string length $x]>0 
     && [regexp {^(.+?)(<img alt="syntax diagram .*)$} $x all prefix suffix]} {
    append out $prefix
    set x $suffix
    if {[regexp \
           {<img alt="(syntax diagram [-a-z]+)" src="([-./a-z]+\.gif)"} \
           $x all name image]} {
      #puts "DIAGRAM: $file $name $image"
      set req $name
      regsub {^(\.\./)+} $image {} img2
      set rno R-[md5file-10x8 doc/$img2]
      set shortrno [string range $rno 0 12]
      append out "<a name=\"$rno\"></a><font color=\"blue\"><b>"
      set link "<a href=\"$matrixpath#$rno\" style=\"color: #0000ff\">"
      append out "$link$shortrno</a>:\[</b></font>\n"
      if {$proof($rno)>=2} {
        set clr green
      } elseif {$proof($rno)==1} {
        set clr orange
      } else {
        set clr red
      }
      append out "<img border=3 style=\"border-color: $clr\" src=\"$image\">"
      append out "<font color=\"blue\"><b>\]</b></font>\n"
      regsub {.+?>} $x {} x
    }
  }
  append out $x
  set outfd [open $outfile w]
  puts -nonewline $outfd $out
  close $outfd
}
puts ""
