#!/usr/bin/tclsh
#
# This script processes raw documentation source text into its final form 
# for display.  The processing actions are described below.
#
# Invoke this command as follows:
#
#       tclsh wrap.tcl $(DOC) $(SRC) $(DEST) source1.in source2.in ...
#
# The $(DOC) and $(SRC) values are the names of directories containing
# the documentation source and program source.  $(DEST) is the name of
# of the directory where generated HTML is written.  sourceN.in is the
# input file to be processed.  The output is sourceN.html in the
# $(DEST) directory.
#
# Changes made to the source files:
#
#     *  An appropriate header (containing the SQLite logo and standard
#        menu bar) is prepended to the file.  
#
#     *  Any <title>...</title> in the input is moved into the prepended
#        header.
#
#     *  An appropriate footer is appended.
#
#     *  Scripts within <tcl>...</tcl> are evaluated.  Output that
#        is emitted from these scripts by "hd_puts" or "hd_resolve"
#        procedures appears in place of the original script.
#
#     *  Hyperlinks within [...] are resolved.
#
# A two-pass algorithm is used.  The first pass collects the names of
# hyperlink targets, requirements text, and other global information.
# The second pass uses the data gathered on the first pass to generate
# the final output.
#
set DOC [lindex $argv 0]
set SRC [lindex $argv 1]
set DEST [lindex $argv 2]
set HOMEDIR [pwd]            ;# Also remember our home directory.

source [file dirname [info script]]/pages/fancyformat.tcl
source [file dirname [info script]]/document_header.tcl
source [file dirname [info script]]/common_links.tcl

# Open the SQLite database.
#
sqlite3 db docinfo.db
db eval {
  ATTACH 'history.db' AS history;
  BEGIN;
  DELETE FROM link;
  DELETE FROM keyword;
  DELETE FROM fragment;
  DELETE FROM page;
  DELETE FROM alttitle;
  DROP TABLE IF EXISTS expage;
}

# Load the syntax diagram linkage data
#
source $DOC/art/syntax/syntax_linkage.tcl

# Utility proc that removes excess leading whitespace.
#
proc hd_trim {txt} {
  regsub -all {\n\s+} $txt "\n" txt
  regsub -all {\s+\n} $txt "\n" txt
  return [string trim $txt]
}

# This is the first-pass implementation of procedure that renders
# hyperlinks.  Do not even bother trying to do anything during the
# first pass.  We have to collect keyword information before the
# hyperlinks are meaningful.  
#
proc hd_resolve {text} {
  hd_puts $text
}

# This is the second-pass implementation of the procedure that
# renders hyperlinks.  Convert all hyperlinks in $text into 
# appropriate <a href=""> markup.
#
# Links to keywords within the same main file are resolved using
# $::llink() if possible.  All other links and links that could
# not be resolved using $::llink() are resolved using $::glink().
# 
proc hd_resolve_2ndpass {text} {
  regsub -all {<yyterm>} $text {<span class='yyterm'>} text
  regsub -all {</yyterm>} $text {</span>} text
  regsub -all {\[(.*?)\]} $text \
      "\175; hd_resolve_one \173\\1\175; hd_puts \173" text
  eval "hd_puts \173$text\175"
}
proc hd_resolve_one {x} {
  if {[string is integer $x]} {
    hd_puts \[$x\]
    return
  }
  if {[string match {dateof:3.*} $x]} {
    set x [string range $x 7 end]
    if {[info exists ::dateofversion($x)]} {
      hd_puts $::dateofversion($x)
    } else {
      puts stderr "*** unresolved date: '\[dateof:$x\]' ***"
      hd_puts "<font color='red'>0000-00-00</font>"
    }
    return
  }
  set x2 [split $x |]
  set kw [string trim [lindex $x2 0]]
  if {[llength $x2]==1} {
    set content $kw
    regsub {\([^)]*\)} $content {} kw
    if {![regexp {^http} $kw]} {regsub {=.*} $kw {} kw}
  } else {
    set content [string trim [lindex $x2 1]]
  }
  if {![regexp {^https?:} $kw]} {
    regsub -all {[^a-zA-Z0-9_.#/ -]} $kw {} kw
  }
  global hd llink glink backlink
  if {$hd(enable-main)} {
    set fn $hd(fn-main)
    if {[regexp {^https?:} $kw]} {
      puts -nonewline $hd(main) \
        "<a href=\"$kw\">$content</a>"
    } elseif {[regexp {^[Tt]icket #(\d+)$} $kw all tktid]} {
      set url http://www.sqlite.org/cvstrac/tktview?tn=$tktid
      puts -nonewline $hd(main) \
        "<a href=\"$url\">$content</a>"
    } elseif {[info exists llink($fn:$kw)]} {
      puts -nonewline $hd(main) \
        "<a href=\"$hd(rootpath-main)$llink($fn:$kw)\">$content</a>"
    } elseif {[info exists glink($kw)]} {
      puts -nonewline $hd(main) \
        "<a href=\"$hd(rootpath-main)$glink($kw)\">$content</a>"
    } elseif {[regexp {\.gif$} $kw]} {
      puts -nonewline $hd(main) \
        "<img src=\"$hd(rootpath-main)images/$kw\">"
    } else {
      puts stderr "ERROR: unknown hyperlink target: $kw"
      puts -nonewline $hd(main) "<font color=\"red\">$content</font>"
    }
    if {$hd(fragment)!=""} {
      lappend backlink($kw) $fn#$hd(fragment)
    } else {
      lappend backlink($kw) $fn
    }
  }
  if {$hd(enable-aux)} {
    if {[regexp {^https?:} $kw]} {
      puts -nonewline $hd(aux) \
        "<a href=\"$kw\">$content</a>"
    } elseif {[regexp {^[Tt]icket #(\d+)$} $kw all tktid]} {
      set url http://www.sqlite.org/cvstrac/tktview?tn=$tktid
      puts -nonewline $hd(aux) \
        "<a href=\"$url\">$content</a>"
    } elseif {[info exists glink($kw)]} {
      puts -nonewline $hd(aux) \
        "<a href=\"$hd(rootpath-aux)$glink($kw)\">$content</a>"
    } elseif {[regexp {\.gif$} $kw]} {
      puts -nonewline $hd(main) \
        "<img src=\"$hd(rootpath-aux)images/$kw\">"
    } else {
      puts stderr "ERROR: unknown hyperlink target: $kw"
      puts -nonewline $hd(aux) "<font color=\"red\">$content</font>"
    }
    if {$hd(aux-fragment)!=""} {
      lappend backlink($kw) $hd(fn-aux)#$hd(aux-fragment)
    } else {
      lappend backlink($kw) $hd(fn-aux)
    }
  }
}


# Convert the keyword $kw into an appropriate relative URI
# This is a helper routine to hd_list_of_links
#
proc hd_keyword_to_uri {kw} {
  global hd llink glink
  if {[string match {*.html} $kw]} {return $kw}
  if {$hd(enable-main)} {
    set fn $hd(fn-main)
    set res ""
    if {[info exists llink($fn:$kw)]} {
      set res "$hd(rootpath-main)$llink($fn:$kw)"
    } elseif {[info exists glink($kw)]} {
      set res "$hd(rootpath-main)$glink($kw)"
    }
    if {$res!=""} {
      if {$hd(fragment)!=""} {
        lappend backlink($kw) $fn#$hd(fragment)
      } else {
        lappend backlink($kw) $fn
      }
    }
    return $res
  }
  if {$hd(enable-aux)} {
    if {[info exists glink($kw)]} {
      if {$hd(aux-fragment)!=""} {
        lappend backlink($kw) $hd(fn-aux)#$hd(aux-fragment)
      } else {
        lappend backlink($kw) $hd(fn-aux)
      }
      return $hd(rootpath-aux)$glink($kw)
    }
  }
  return ""
}

# Generate a Javascript table containing the URL and Label from $lx
# This is a helper routine for hd_list_of_links.
#
proc hd_list_of_links_javascript {lx} {
  set sep {[}
  foreach entry $lx {
    foreach {link label s} $entry break
    set url [hd_keyword_to_uri $link]
    hd_puts "${sep}{\"u\":\"$url\",\"x\":\"$label\",\"s\":$s}"
    set sep ",\n"
  }
  hd_putsnl "\];"
}

# Output HTML/JS that displays the list $lx in multiple columns
# under the assumption that each column is $w pixels wide.  The
# number of columns automatically adjusts to fill the available
# screen width.
#
# If $title is not an empty string, then it is used as a title for
# the list of links
#
# $lx is a list of triples.  Each triple is {KEYWORD LABEL S}.  The
# S determines a suffix added to each list element:
#
#    0:     Add nothing (the default and common case)
#    1:     Add the "(exp)" suffix
#    2:     Strike through the text and do not hyperlink
#    3:     Strike through the text and add &sup1
#    4:     Add &sup2
#    5:     Add &sup3
#
proc hd_list_of_links {title w lx} {
  global listcount hd
  if {![info exists listcount]} {
    set listcount 1
  } else {
    incr listcount
  }
  set tx listtab$listcount
  set vx listitems$listcount
  hd_puts "<style>\n#$tx tr td {vertical-align:top;}\n"
  hd_puts "</style>\n"
  hd_putsnl "<table id='$tx' width='100%'></table>"
  hd_putsnl "<script>"
  hd_puts "var $vx = "
  if {$hd(enable-main) && $hd(enable-aux)} {
    set hd(enable-main) 0
    hd_list_of_links_javascript $lx
    set hd(enable-main) 1
    set hd(enable-aux) 0
    hd_list_of_links_javascript $lx
    set hd(enable-aux) 1
  } else {
    hd_list_of_links_javascript $lx
  }
  hd_putsnl "var j = 0;"
  hd_putsnl "var w = Math.max(document.documentElement.clientWidth, \
             window.innerWidth || 0);"
  hd_putsnl "var nCol = Math.floor(w/$w);"
  hd_putsnl "if(nCol<=0) nCol=1;"
  hd_putsnl "var nRow = Math.ceil(($vx.length+1)/nCol);"
  if {$title!=""} {
    hd_putsnl "var h=\"<tr><td colspan=\"+nCol;"
    hd_putsnl "h += \">$title</td></tr><tr><td><ul class='multicol_list'>\""
  } else {
    hd_putsnl "var h=\"<tr><td><ul class='multicol_list'>\""
  }
  hd_putsnl "var ea"
  hd_putsnl "for(var i=0; i<$vx.length; i++){"
  hd_putsnl "  if( (++j)>nRow ){"
  hd_putsnl "    h += \"</ul></td>\\n<td><ul class='multicol_list'>\\n\";"
  hd_putsnl "    j = 1;"
  hd_putsnl "  }"
  hd_putsnl "  if($vx\[i\].u==\"\" || $vx\[i\].s==2){"
  hd_putsnl "    h += \"<li>\""
  hd_putsnl "    ea = \"\""
  hd_putsnl "  }else{"
  hd_putsnl "    h += \"<li><a href='\";"
  hd_putsnl "    h += $vx\[i\].u;"
  hd_putsnl "    h += \"'>\";"
  hd_putsnl "    ea = \"</a>\""
  hd_putsnl "  }"
  hd_putsnl "  if($vx\[i\].s==2 || $vx\[i\].s==3) h += \"<s>\""
  hd_putsnl "  h += $vx\[i\].x;"
  hd_putsnl "  if($vx\[i\].s==2 || $vx\[i\].s==3) h += \"</s>\""
  hd_putsnl "  h += ea"
  hd_putsnl "  if($vx\[i\].s==1) h += \"<small><i>(exp)</i></small>\\n\";"
  hd_putsnl "  if($vx\[i\].s==3) h += \"&sup1\\n\";"
  hd_putsnl "  if($vx\[i\].s==4) h += \"&sup2\\n\";"
  hd_putsnl "  if($vx\[i\].s==5) h += \"&sup3\\n\";"
  hd_putsnl "}"
  hd_putsnl "document.getElementById(\"$tx\").innerHTML = h;"
  hd_putsnl "</script>"
}

# Record the fact that all keywords given in the argument list should
# cause a jump to the current location in the current file.
#
# If only the main output file is open, then all references to the
# keyword jump to the main output file.  If both main and aux are
# open then references from within the main file jump to the main file
# and all other references jump to the auxiliary file.
#
# This procedure is only active during the first pass when we are
# collecting hyperlink information.  This procedure is redefined to
# be a no-op before the start of the second pass.
#
proc hd_keywords {args} {
  global glink llink hd
  if {$hd(fragment)==""} {
    set lurl $hd(fn-main)
  } else {
    set lurl "#$hd(fragment)"
  }
  set fn $hd(fn-main)
  if {[info exists hd(aux)]} {
    set gurl $hd(fn-aux)
    if {$hd(aux-fragment)!=""} {
      append gurl "#$hd(aux-fragment)"
    }
  } else {
    set gurl {}
    if {$hd(fragment)!=""} {
      set lurl $hd(fn-main)#$hd(fragment)
    }
  }
  set override_flag 0
  foreach a $args {
    if {[regexp {^-+(.*)} $a all param] && ![regexp {^-D} $a]} {
      switch $param {
        "override" {
           set override_flag 1
        }
        default {
           puts stderr "ERROR: unknown parameter: $a"
        }
      }
      continue
    }
    if {[regexp {^\*} $a]} {
      set visible 0
      set a [string range $a 1 end]
    } else {
      set visible 1
    }
    regsub -all {[^a-zA-Z0-9_.#/ -]} $a {} kw
    if {[info exists glink($kw)]} {
      if {[info exists hd(aux)] && $glink($kw)==$hd(fn-aux)} {
        db eval {DELETE FROM keyword WHERE kw=$kw}
      } elseif {$override_flag==0} {
        puts stderr "WARNING: duplicate keyword \"$kw\" - $glink($kw) and $lurl"
      }
    }
    if {$gurl==""} {
      set glink($kw) $lurl
      db eval {INSERT OR IGNORE INTO keyword(kw,fragment,indexKw) 
                VALUES($a,$lurl,$visible)}
    } else {
      set glink($kw) $gurl
      set llink($fn:$kw) $lurl
      db eval {INSERT OR IGNORE INTO keyword(kw,fragment,indexKw) 
                VALUES($a,$gurl,$visible)}
    }
  }
}

# Start a new fragment in the main file.  Give the new fragment the
# indicated name.  Any keywords defined after this point will refer
# to the fragment, not to the beginning of the file.
#
proc hd_fragment {name args} {
  global hd
  set hd(fragment) $name
  puts $hd(main) "<a name=\"$name\"></a>"
  if {$hd(enable-aux)} {
    puts $hd(aux) "<a name=\"$name\"></a>"
    set hd(aux-fragment) $name
  }
  eval hd_keywords $args
}

# Write raw output to both the main file and the auxiliary.  Only write
# to files that are enabled.
#
proc hd_puts {text} {
  global hd
  if {$hd(enable-main)} {
    set fn $hd(fn-main)
    puts -nonewline $hd(main) $text
  }
  if {$hd(enable-aux)} {
    set fn $hd(fn-aux)
    puts -nonewline $hd(aux) $text
  }
  
  # Our pagelink processing based off the globals
  # llink, glink, and backlink generated during hd_resolve
  # processing doesn't catch links outputted directly
  # with hd_puts.  This code attempts to add those links to
  # our pagelink array.
  global pagelink
  set refs [regexp -all -inline {href=\"(.*?)\"} $text]
  foreach {href ref} $refs {
    regsub {#.*} $ref {} ref2
    regsub {http:\/\/www\.sqlite\.org\/} $ref2 {} ref3
    regsub {\.\.\/} $ref3 {} ref4
    if {[regexp {^http} $ref4]} continue
    if {$ref4==""} continue
    if {[regexp {\.html$} $ref4]} {
      lappend pagelink($ref4) $fn
    }
  }
}
proc hd_putsnl {text} {
  hd_puts $text\n
}

# Enable or disable the main output file.
#
proc hd_enable_main {boolean} {
  global hd
  set hd(enable-main) $boolean
}

# Enable or disable the auxiliary output file.
#
proc hd_enable_aux {boolean} {
  global hd
  set hd(enable-aux) $boolean
}
set hd(enable-aux) 0

# Open the main output file.  $filename is relative to $::DEST.  
#
proc hd_open_main {filename} {
  global hd DEST
  hd_close_main
  set hd(fn-main) $filename
  set hd(rootpath-main) [hd_rootpath $filename]
  set hd(main) [open $DEST/$filename w]
  set hd(enable-main) 1
  set hd(enable-aux) 0
  set hd(fragment) {}
  global pagelink
  lappend pagelink($filename) $filename
}

# If $filename is a path from $::DEST to a file, return a path
# from the directory containing $filename back to the directory $::DEST.
#
proc hd_rootpath {filename} {
  set up {}
  set n [llength [split $filename /]]
  if {$n<=1} {
    return {}
  } else {
    return [string repeat ../ [expr {$n-1}]]
  }
}

# Close the main output file.
#
proc hd_close_main {} {
  global hd
  hd_close_aux
  if {[info exists hd(main)]} {
    puts $hd(main) $hd(footer)
    close $hd(main)
    unset hd(main)
  }
}

# Open the auxiliary output file.
#
# Most documents have only a main file and no auxiliary.  However, some
# large documents are broken up into smaller pieces where each smaller piece
# is an auxiliary file.  There will typically be either many auxiliary files
# or no auxiliary files associated with each main file.
#
proc hd_open_aux {filename} {
  global hd DEST
  hd_close_aux
  set hd(fn-aux) $filename
  set hd(rootpath-aux) [hd_rootpath $filename]
  set hd(aux) [open $DEST/$filename w]
  set hd(enable-aux) 1
  set hd(aux-fragment) {}
  global pagelink
  lappend pagelink($filename) $filename
}

# Close the auxiliary output file
#
proc hd_close_aux {} {
  global hd
  if {[info exists hd(aux)]} {
    puts $hd(aux) $hd(footer)
    close $hd(aux)
    unset hd(aux)
    set hd(enable-aux) 0
    set hd(enable-main) 1
  }
}


# hd_putsin4 is like puts except that it removes the first 4 indentation
# characters from each line.  It also does variable substitution in
# the namespace of its calling procedure.
#
proc putsin4 {fd text} {
  regsub -all "\n    " $text \n text
  puts $fd [uplevel 1 [list subst -noback -nocom $text]]
}

# Return a globally unique object id
#
set hd_id_counter 0
proc hd_id {} {
  global hd_id_counter
  incr hd_id_counter
  return x$hd_id_counter
}

# A procedure to write the common header found on every HTML file on
# the SQLite website.
#
#####################
# NOTE:  This code is copied and reused in matrix.tcl.  When making
# changes to this implementation, be sure to also change matrix.tcl.
#
proc hd_header {title {srcfile {}}} {
  global hd
  set saved_enable $hd(enable-main)
  if {$srcfile==""} {
    set fd $hd(aux)
    set path $hd(rootpath-aux)
  } else {
    set fd $hd(main)
    set path $hd(rootpath-main)
  }

  puts $fd [document_header $title $path]
  if {$srcfile!=""} {
    if {[file exists DRAFT]} {
      set hd(footer) [hd_trim {
        <p align="center"><font size="6" color="red">*** DRAFT ***</font></p>
      }]
    } else {
      set hd(footer) {}
    }
  } else {
    set hd(enable-main) $saved_enable
  }
}

# Insert a bubble syntax diagram into the output.
#
proc BubbleDiagram {name {anonymous_flag 0}} {
  global hd

  #if {!$anonymous_flag} {
  #  hd_resolve "<h4>\[$name:\]</h4>"
  #}
  hd_resolve "<p><b>\[$name:\]</b></p>"
  set alt "alt=\"syntax diagram $name\""
  if {$hd(enable-main)} {
    puts $hd(main) "<div class='imgcontainer'>\n\
        <img $alt src=\"$hd(rootpath-main)images/syntax/$name.gif\"></img>\n\
        </div>"
  }
  if {$hd(enable-aux)} {
    puts $hd(aux) "<div class='imgcontainer'>\n\
        <img $alt src=\"$hd(rootpath-aux)images/syntax/$name.gif\"></img>\n\
        </div>"
  }
}
proc HiddenBubbleDiagram {name} {
  global hd
  set alt "alt=\"syntax diagram $name\""
  hd_resolve "<p><b>\[$name:\]</b> "
  if {$hd(enable-main)} {
    set a [hd_id]
    set b [hd_id]
    puts $hd(main) \
     "<button id='$a' onclick='hideorshow(\"$a\",\"$b\")'>show</button>\
      </p>\n\
      <div id='$b' style='display:none;' class='imgcontainer'>\n\
      <img $alt src=\"$hd(rootpath-main)images/syntax/$name.gif\"></img>\n\
      </div>"
  }
  if {$hd(enable-aux)} {
    set a [hd_id]
    set b [hd_id]
    puts $hd(aux) \
     "<button id='$a' onclick='hideorshow(\"$a\",\"$b\")'>show</button>\
      </p>\n\
      <div id='$b' style='display:none;' class='imgcontainer'>\n\
      <img $alt src=\"$hd(rootpath-aux)images/syntax/$name.gif\"></img>\n\
      </div>"
  }
}
proc RecursiveBubbleDiagram_helper {class name openlist exclude} {
  global hd syntax_linkage
  set alt "alt=\"syntax diagram $name\""
  hd_resolve "<p><b>\[$name:\]</b>\n"
  set a [hd_id]
  set b [hd_id]
  set openflag 0
  set open2 {}
  foreach x $openlist {
    if {$x==$name} {
      set openflag 1
    } else {
      lappend open2 $x
    }
  }
  if {$openflag} {
    puts $hd($class) \
      "<button id='$a' onclick='hideorshow(\"$a\",\"$b\")'>hide</button></p>\n\
       <div id='$b' class='imgcontainer'>\n\
       <img $alt src=\"$hd(rootpath-$class)images/syntax/$name.gif\" />"
  } else {
    puts $hd($class) \
      "<button id='$a' onclick='hideorshow(\"$a\",\"$b\")'>show</button></p>\n\
       <div id='$b' style='display:none;' class='imgcontainer'>\n\
       <img $alt src=\"$hd(rootpath-$class)images/syntax/$name.gif\" />"
  }
  if {[info exists syntax_linkage($name)]} {
    foreach {cx px} $syntax_linkage($name) break
    foreach c $cx {
      if {[lsearch $exclude $c]>=0} continue
      RecursiveBubbleDiagram_helper $class $c $open2 [concat $exclude $cx]
    }  
  }
  puts $hd($class) "</div>"
}
proc RecursiveBubbleDiagram {args} {
  global hd
  set show 1
  set a2 {}
  foreach name $args {
    if {$name=="--initially-hidden"} {
      set show 0
    } else {
      lappend a2 $name
    }
  }
  if {$show} {
    set showlist $a2
  } else {
    set showlist {}
  }
  set name [lindex $a2 0]
  if {$hd(enable-main)} {
    RecursiveBubbleDiagram_helper main $name $showlist $name
  }
  if {$hd(enable-aux)} {
    RecursiveBubbleDiagram_helper aux $name $showlist $name
  }
}



# Insert a See Also line for related bubble

# Record a requirement.  This procedure is active only for the first
# pass.  This procedure becomes a no-op for the second pass.  During
# the second pass, requirements listing report generators can use the
# data accumulated during the first pass to construct their reports.
#
# If the "verbatim" argument is true, then the requirement text is
# rendered as is.  In other words, the requirement text is assumed to
# be valid HTML with all hyperlinks already resolved.  If the "verbatim"
# argument is false (the default) then the requirement text is rendered
# using hd_render which will find an expand hyperlinks within the text.
#
# The "comment" argument is non-binding commentary and explanation that
# accompanies the requirement.
#
proc hd_requirement {id text derivedfrom comment} {
  global ALLREQ ALLREQ_DERIVEDFROM ALLREQ_COM
  if {[info exists ALLREQ($id)]} {
    puts stderr "duplicate requirement label: $id"
  }
  set ALLREQ_DERIVEDFROM($id) $derivedfrom
  set ALLREQ($id) $text
  set ALLREQ_COM($id) $comment
}

# Read a block of requirements from an ASCII text file.  Store the
# information obtained in a global variable named by the second parameter.
#
proc hd_read_requirement_file {filename varname} {
  global hd_req_rdr
  hd_reset_requirement_reader
  set in [open $filename]
  while {![eof $in]} {
    set line [gets $in]
    if {[regexp {^(HLR|UNDEF|SYSREQ) +([LHSU]\d+) *(.*)} $line all type rn df]} {
      hd_add_one_requirement $varname
      set hd_req_rdr(rn) $rn
      set hd_req_rdr(derived) $df
    } elseif {[string trim $line]==""} {
      if {$hd_req_rdr(body)==""} {
        set hd_req_rdr(body) $hd_req_rdr(comment)
        set hd_req_rdr(comment) {}
      } else {
        append hd_req_rdr(comment) \n
      }
    } else {
      append hd_req_rdr(comment) $line\n
    }
  }
  hd_add_one_requirement $varname
  close $in
  
}
proc hd_reset_requirement_reader {} {
  global hd_req_rdr
  set hd_req_rdr(rn) {}
  set hd_req_rdr(comment) {}
  set hd_req_rdr(body) {}
  set hd_req_rdr(derived) {}
}
proc hd_add_one_requirement {varname} {
  global hd_req_rdr
  set rn $hd_req_rdr(rn)
  if {$rn!=""} {
    if {$hd_req_rdr(body)==""} {
      set hd_req_rdr(body) $hd_req_rdr(comment)
      set hd_req_rdr(comment) {}
    }
    set b [string trim $hd_req_rdr(body)]
    set c [string trim $hd_req_rdr(comment)]
    set ::${varname}($rn) [list $hd_req_rdr(derived) $b $c]
    lappend ::${varname}(*) $rn
  }
  hd_reset_requirement_reader
}

# First pass.  Process all files.  But do not render hyperlinks.
# Merely collect keyword information so that hyperlinks can be
# correctly rendered on the second pass.
#
foreach infile [lrange $argv 3 end] {
  cd $HOMEDIR
  puts "Processing $infile"
  set fd [open $infile r]
  set in [read $fd]
  close $fd
  if {[regexp {<(fancy_format|table_of_contents)>} $in]} { set in [addtoc $in] }
  set title {No Title}
  regexp {<title>([^\n]*)</title>} $in all title
  regsub {<title>[^\n]*</title>} $in {} in
  set outfile [file root [file tail $infile]].html
  hd_open_main $outfile
  db eval {
    INSERT INTO page(filename,pagetitle)
    VALUES($outfile,$title);
  }
  set h(pageid) [db last_insert_rowid]
  while {[regexp {<alt-title>([^\n]*)</alt-title>} $in all alttitle]} {
    regsub {<alt-title>[^\n]*</alt-title>} $in {} in
    db eval {
      INSERT INTO alttitle(alttitle,pageid) VALUES($alttitle,$h(pageid));
    }
  }
  hd_header $title $infile
  regsub -all {<tcl>} $in "\175; eval \173" in
  regsub -all {</tcl>} $in "\175; hd_puts \173" in
  eval "hd_puts \173$in\175"
  cd $::HOMEDIR
  hd_close_main
}

# Second pass.  Process all files again.  This time render hyperlinks
# according to the keyword information collected on the first pass.
#
proc hd_keywords {args} {}
rename hd_resolve {}
rename hd_resolve_2ndpass hd_resolve
proc hd_requirement {args} {}
set footertcl [file normalize [file join $::DOC pages footer.tcl]]
foreach infile [lrange $argv 3 end] {
  cd $HOMEDIR
  puts "Processing $infile"
  set fd [open $infile r]
  set in [read $fd]
  close $fd
  regsub -all {<alt-title>[^\n]*</alt-title>} $in {} in
  if {[regexp {<(fancy_format|table_of_contents)>} $in]} { set in [addtoc $in] }
  set title {No Title}
  regexp {<title>([^\n]*)</title>} $in all title
  regsub {<title>[^\n]*</title>} $in {} in
  set outfile [file root [file tail $infile]].html
  hd_open_main $outfile
  hd_header $title $infile
  regsub -all {<tcl>} $in "\175; eval \173" in
  regsub -all {</tcl>} $in "\175; hd_resolve \173" in
  eval "hd_resolve \173$in\175"
  # source $footertcl
  cd $::HOMEDIR
  hd_close_main
}

# Generate a document showing the hyperlink keywords and their
# targets.
#
hd_open_main doc_keyword_crossref.html
hd_header {Keyword Crossreference} $DOC/wrap.tcl
hd_puts "<ul>"
foreach x [lsort -dict [array names glink]] {
  set y $glink($x)
  hd_puts "<li>$x - <a href=\"$y\">$y</a></li>"
  lappend revglink($y) $x
}
hd_puts "</ul>"
hd_close_main

hd_open_main doc_target_crossref.html
hd_header {Target Crossreference} $DOC/wrap.tcl
hd_putsnl "<ul>"
foreach y [lsort [array names revglink]] {
  hd_putsnl "<li><a href=\"$y\">$y</a> &rarr; [lsort $revglink($y)]</li>"
}
hd_putsnl "</ul>"
hd_close_main

hd_open_main doc_backlink_crossref.html
hd_header {Backlink Crossreference} $DOC/wrap.tcl
hd_puts "<ul>"
foreach kw [lsort -nocase [array names backlink]] {
  hd_puts "<li>$kw &rarr;"
  set prev {}
  foreach ref [lsort $backlink($kw)] {
    if {$ref==$prev} continue
    set prev $ref
    hd_putsnl "  <a href=\"$ref\">$ref</a>"
  }
}
hd_putsnl "</ul>"
hd_close_main

hd_open_main doc_pagelink_crossref.html
hd_header {Pagelink Crossreference} $DOC/wrap.tcl
hd_puts "<p>Key: Target_Page &rarr; pages that have hyperlinks to the target page.</p>"
hd_puts "<p>Pages matching (news|changes|releaselog|\[0-9]to\[0-9]|&#94;doc_.*_crossref) are skipped.</p>"
hd_puts "<ul>"
foreach y [lsort [array names revglink]] {
  regsub {#.*} $y {} y2
  foreach kw [lsort $revglink($y)] {
    if {[info exists backlink($kw)]} {
      foreach ref [lsort $backlink($kw)] {
        regsub {#.*} $ref {} ref2
        lappend pagelink($y2) $ref2
      }
    }
  }
}
foreach y [lsort [array names pagelink]] {
  if {[regexp {(news|changes|releaselog|[0-9]to[0-9]|^doc_.*_crossref)} $y]} continue
  hd_putsnl "<li><a href=\"$y\">$y</a> &rarr; "
  set prev {}
  foreach ref [lsort $pagelink($y)] {
    if {$ref==$prev} continue
    if {$ref==$y} continue
    if {[regexp {(news|changes|releaselog|[0-9]to[0-9]|^doc_.*_crossref)} $ref]} continue
    hd_puts "<a href=\"$ref\">$ref</a> "
    set prev $ref
  }
  hd_putsnl "</li>"
}
hd_puts "</ul>"
hd_close_main
db eval COMMIT

puts "Writing glink and llink arrays to 'doc_vardump.txt'"
set fd [open doc_vardump.txt wb]
foreach a {glink llink} {
  foreach v [lsort [array names $a]] {
    puts $fd "set ${a}($v) [list [set ${a}($v)]]"
  }
}
close $fd
