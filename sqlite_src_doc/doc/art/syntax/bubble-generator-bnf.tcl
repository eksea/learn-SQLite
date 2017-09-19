#!/bin/tclsh
#
# Run this TCL script to generate syntax bubble diagrams from
# text descriptions.
#
# This version generates a pure HTML table based version with
# no graphics, all in one file named "all-text.html".  It may
# be useful to people wanting text search or screen reader 
# support.

source [file join [file dirname [info script]] bubble-generator-data.tcl]

# padding (diff betwee font1 and font2)
set pad "6px"
# used for bubble text
set font1 "12px"
# used for bnf syntax [ ] | etc.
set font2 "18px"
# used for everything else (~ font1+5)
set font3 "16px"

# Draw a bubble containing $txt. 
#
proc draw_bubble {txt} {
  global font1

  if {$txt=="nil"} {
    return [list 1 ""]
  }

  if {[regexp {^/[a-z]} $txt]} {
    set txt [string range $txt 1 end]
    set istoken 1
  } elseif {[regexp {^[a-z]} $txt]} {
    set istoken 0
  } else {
    set istoken 1
  }

  if {!$istoken} {
    set txt "&lt;<a href=\"#$txt\">$txt</a>&gt;"
  }
  
  return [list 1 "<font style=\"white-space:nowrap; font-size:$font1;\">$txt</font>"]
}

# Draw a sequence of terms from left to write.  Each element of $lx
# descripts a single term.
#
proc draw_line {lx} {
  global font1

  set n [llength $lx]

  set h 1
  set content ""
  set i 0
  foreach term $lx {
    incr i

    set rc [draw_diagram $term]
    set th [lindex $rc 0]
    set tcontent [lindex $rc 1]

    if { $tcontent != "" } {
      if { $content != "" } {
        set content "$content&nbsp;$tcontent"
      } else {
        set content "$tcontent"
      }
      if { $th > $h } { set h $th }
    }
  }
  set content "$content"

  return [list $h $content]
}

# Draw a sequence of terms from top to bottom.
#
proc draw_stack {indent lx} {
  global font1

  set n [llength $lx]

  set h 0
  set content ""

  set i 0
  foreach term $lx {
    if { $term != "" } {
      set rc [draw_diagram $term]
      set th [lindex $rc 0]
      set tcontent [lindex $rc 1]
      set h [ expr { $h + $th } ]
      
      incr i
      if {$i == 1} {
        set content "$tcontent"
      } else {
        set content "$content<br>$tcontent"
      }
    }
  }

  return [list $h $content]
}

proc draw_loop {forward back} {
  global font1

  set h 0
  set content ""

  set rc [draw_diagram $forward]
  set th [lindex $rc 0]
  set tcontent [lindex $rc 1]

  if { $tcontent != "" } {
    set content "$tcontent"
    if { $th > $h } { set h $th }
  }
  
  set rc [draw_line $back]
  set th [lindex $rc 0]
  set tcontent [lindex $rc 1]

  if { $tcontent != "" } {
    if { $content != "" } {
      set content "$content \[&nbsp;$tcontent&nbsp;$content&nbsp;]*"
    } else {
      set content "\[&nbsp;$tcontent&nbsp;]*"
    }
    if { $th > $h } { set h $th }
  }

  return [list $h $content]
}

proc draw_or {lx} {
  global font1

  set n [llength $lx]

  set h 0
  if {$n < 1} {
    set content ""
  } else {
    set content ""
    set i 0
    set req "<font style=\"vertical-align:top; font-size:$font1;\">1</font>"
    foreach term $lx {

      set rc [draw_diagram $term]
      set th [lindex $rc 0]
      set tcontent [lindex $rc 1]

      if { $tcontent == "" } {
        set req ""
      } else {
        incr i
        if {$i == 1} {
          set content "$tcontent"
        } else {
          set content "$content | $tcontent"
        }
        if { $th > $h } { set h $th }
      }

    }
  }
  set content "\[&nbsp;$content&nbsp;]$req"
  return [list $h $content]
}

proc draw_diagram {spec} {
  global font1

  set n [llength $spec]
  set cmd [lindex $spec 0]

  if {$n==1} {
    set rc [draw_bubble $spec]
  } elseif {$n==0} {
    set rc [draw_bubble nil]
  } elseif {$cmd=="line"} {
    set rc [draw_line [lrange $spec 1 end]]
  } elseif {$cmd=="stack"} {
    set rc [draw_stack 0 [lrange $spec 1 end]]
  } elseif {$cmd=="indentstack"} {
    set rc [draw_stack $::HSEP [lrange $spec 1 end]]
  } elseif {$cmd=="loop"} {
    set rc [draw_loop [lindex $spec 1] [lindex $spec 2]]
  } elseif {$cmd=="toploop"} {
    set rc [draw_loop [lindex $spec 1] [lindex $spec 2]]
  } elseif {$cmd=="or"} {
    set rc [draw_or [lrange $spec 1 end]]
  } elseif {$cmd=="opt"} {
    set args [lrange $spec 1 end]
    if {[llength $args]==1} {
      set rc [draw_or [list nil [lindex $args 0]]]
    } else {
      set rc [draw_or [list nil "line $args"]]
    }
  } elseif {$cmd=="optx"} {
    set args [lrange $spec 1 end]
    if {[llength $args]==1} {
      set rc [draw_or [list [lindex $args 0] nil]]
    } else {
      set rc [draw_or [list "line $args" nil]]
    }
  } elseif {$cmd=="tailbranch"} {
    # set rc [draw_tail_branch [lrange $spec 1 end]]
    set rc [draw_or [lrange $spec 1 end]]
  } else {
    error "unknown operator: $cmd"
  }

  set h [lindex $rc 0]
  set content [lindex $rc 1]

  return [list $h $content]
}

proc draw_graph {name spec} {
  global font1 pad

  set cmd1 [lindex $spec 0]
  if { $cmd1 == "or" } {
    set req 1
    set spec1 [lrange $spec 1 end]
    foreach term $spec1 {
      if { $term == "" || $term == "nil"} {
        set req 0
      }
    }
    if { $req == 1 } {
      set content "<table>"
      set h 0
      foreach term $spec1 {
        set rc [ draw_diagram "line [list $term]"]
        set th [lindex $rc 0]
        set tcontent [lindex $rc 1]
        set content "$content<tr><td style=\"font-size:$font1; white-space:nowrap; padding-top:$pad;\">$name</td><td>::=</td><td>$tcontent</td></tr>"
        set h [ expr { $h + $th } ]
      }
      set content "$content</table>"
      return [list $h $content]
    }
  }

  set rc [ draw_diagram "line [list $spec]"]
  set h [lindex $rc 0]
  set content [lindex $rc 1]
  set content "<table><tr><td style=\"font-size:$font1; white-space:nowrap; padding-top:$pad;\">$name</td><td>::=</td><td>$content</td></tr></table>"
  return [list $h $content]
}

set f [open all-bnf.html w]
puts $f "<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 4.01//EN\" \"http://www.w3.org/TR/html4/strict.dtd\">"
puts $f "<html>"
puts $f "<head>"
puts $f "<style type='text/css'>"
puts $f "h3 { font-family:helvetica; font-size:$font3; }"
puts $f "table, tr, td { font-family:helvetica; font-size:$font2; empty-cells:show; border-collapse:separate; border-style:none; vertical-align:top; }"
puts $f "</style>"
puts $f "</head>"
puts $f "<body>"
foreach {name graph} $all_graphs {
  if {$name == "sql-stmt-list" || 1} {
    puts $f "<h3><a name=\"$name\">$name</a>:</h3>"
    set rc [draw_graph $name $graph]
    set h [lindex $rc 0]
    set content [lindex $rc 1]
    puts $f "$content"
  }
}
puts $f "</body>"
puts $f "</html>"
close $f

