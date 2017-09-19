#!/usr/bin/tcl
#
# This script HTMLizes test script and source code files and populates
# the evidence.url column in the docinfo.db database with links to
# anchors within the HTMLized scripts.
#
# Usage:
#
#    tclsh format_evidence SRCCAT DOCDIR FILE...
#
# The SRCCAT argument is the evidence source category.  This must be
# the same string as was passed as the SRCCAT argument to scan_test_cases.tcl.
#
# The DOCDIR argument is the name of the directory into which the HTMLized
# evidence files should be written.
#
# Subsequent arguments are the names of the original evidence files.
#
set SRCCAT [lindex $argv 0]
set DOCDIR [lindex $argv 1]
set filelist [lrange $argv 2 end]

# Open a connection to the docinfo.db database file.
#
sqlite3 db docinfo.db

# Create a new htmlizer object used to transfer content from input
# file $src into output file $dest.
#
proc htmlizer_start {src dest} {
  global h
  set h(in) [open $src r]
  set h(out) [open $dest w]
  set h(linenum) 0
  htmlizer_puts_raw "<html><body><pre>\n"
}

# Read a single line of input.  Remove the trailing \n (if any) and
# return the line.
proc htmlizer_gets {} {
  global h
  incr h(linenum)
  return [format {%06d  } $h(linenum)][gets $h(in)]
}

# Write text to the output file.  The text is written "as is" with no
# escaping of content that might be special to HTML.  There is no \n
# inserted at the end.
#
proc htmlizer_puts_raw {text} {
  global h
  puts -nonewline $h(out) $text
}

# Escape special HTML characters from raw text.
#
proc htmlizer_escape {text} {
  return [string map {& {&amp;} < {&lt;} > {&gt;}} $text]
}

# Write a line of text to output.  Escape any characters that have
# special meaning to HTML.  Add a \n at the end.
#
proc htmlizer_puts {text} {
  global h
  puts $h(out) [htmlizer_escape $text]
}

# Transfer lines from input to output upto but not including line $target
#
proc htmlizer_xfer {target} {
  global h
  while {$h(linenum)<$target-1} {
    htmlizer_puts [htmlizer_gets]
  }
}

# Transfer the remainder of content from input to output and close
# the file descriptors.
#
proc htmlizer_finish {} {
  global h
  while {![eof $h(in)]} {
    set line [htmlizer_gets]
    if {![eof $h(in)]} {
      htmlizer_puts $line
    }
  }
  close $h(in)
  htmlizer_puts_raw "</pre></body></html>\n"
  close $h(out)
}

# This routine does the actual work of HTMLizing a source script.
#
# The input file is named $src.  The HTMLized output should be written
# into $docdir/$dest.  The URL should be $dest with added fragment
# information.  Evidence provided by input file $src can be found in
# the evidence table with srccat=$srccat and srcfile=$srcfile.
#
proc htmlize_evidence {src srccat srcfile docdir dest} {
  htmlizer_start $src $docdir/$dest
  set up [regsub -all {[^/]+} [file dir $dest] ..]
  db eval {
     SELECT srcline, reqno, requirement.srcfile AS fn
       FROM evidence JOIN requirement USING(reqno)
      WHERE evidence.srcfile=$srcfile
        AND evidence.srccat=$srccat
      ORDER BY srcline
  } {
    htmlizer_xfer $srcline
    htmlizer_puts_raw "<a name=\"ln$srcline\"></a>"
    set line [htmlizer_gets]
    if {[regexp {^(.*)(R-\d\d\d[\d-]+)(.*$)} $line all pre link post]} {
       set pre [htmlizer_escape $pre]
       set post [htmlizer_escape $post]
       htmlizer_puts_raw "$pre<a href=\"$up/$fn#$reqno\">$link</a>$post\n"
    } else {
       htmlizer_puts $line
    }
  }
  htmlizer_finish
  db eval {
    UPDATE evidence SET url=$dest || '#ln' || srcline
      WHERE srcfile=$srcfile AND srccat=$srccat
  }
}


# Render evidence
#
db transaction {
  foreach file $filelist {
    set srcfile [file tail $file]
    if {![db exists {
       SELECT 1 FROM evidence WHERE srccat=$SRCCAT AND srcfile=$srcfile
    }]} continue
    regsub -all {[^a-zA-Z0-9]} $file _ cleanname
    file mkdir $DOCDIR/ev/$SRCCAT
    set dest ev/$SRCCAT/[file root $srcfile].html
    htmlize_evidence $file $SRCCAT $srcfile $DOCDIR $dest
  }
}
