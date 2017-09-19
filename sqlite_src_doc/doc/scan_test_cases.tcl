#!/usr/bin/tclsh
#
# This script scans source code and scripts written in C, TCL, and SQL
# looking for comments that indicate that the script provides evidence or
# proof or an implementation for statements in the documentation.  Records
# of this evidence are written into the docinfo.db SQLite database file
# into the evidence table.
#
# The source comments come in several forms.  The most common is a comment
# that betweens at the left margin with "**" or "/*" and with one of the
# following keywords:
#
#     EV:
#     EVIDENCE-OF:
#     IMP:
#     IMPLEMENTATION:
#     ANALYSIS-OF:
#
# Following the keyword is either a requirement number of the form:
#
#     R-00000-00000-00000-00000-00000-00000-00000-00000
#
# Or a prefix of such a requirement (usually the first two 5-digit groups 
# suffice) and/or the original text of the requirement.  Original text can 
# continue onto subsequent lines.  The text is terminated by a blank line
# or by the end of the comment.  If both the requirement number and the
# text are provided, this script verifies that they correspond.
#
# The requirement number can be followed by a comment that is not the
# original requirement text.  This is done when the original requirement
# text is an image or is too long the be practical in a comment but one
# still wants something in the comment to give a clue to the reader what
# the requirement is about.  For example:
#
#    # EVIDENCE-OF: R-41448-54465 -- syntax diagram insert-stmt
#
# The "--" following the requirement number is what identifies the
# follow-on text as a comment rather than requirement text.
#
# The second form of the source comments are single-line comments that
# follow these templates:
#
#     /* R-00000-00000... */
#     /* EV: R-00000-00000... */
#     /* IMP: R-00000-00000... */
#
# The comment must contain a requirement number or requirement number
# prefix.  The TYPE of this comment is "assert" if it follows an "assert()"
# macro or "testcase" if it follows a "testcase()" macro, or "evidence" if
# the "EV:" template is used or "implementation" if the "IMP:" template is
# used, otherwise "implementation".
#
#
# COMMAND LINE:
#
# Use as follows:
#
#     tclsh scan_test_cases.tcl SRCCAT DIR/*.test  >>output.txt
#
# The SRCCAT argument specifies the source file category.
#
##############################################################################
#
set SRCCAT [lindex $argv 0]
if {$SRCCAT=="-reset"} {
  set RESET 1
  set argv [lrange $argv 1 end]
  set SRCCAT [lindex $argv 0]
} else {
  set RESET 0
}
regsub {/.*} $SRCCAT {} SRCCLASS
set FILELIST [lrange $argv 1 end]
sqlite3 db docinfo.db

proc output_one_record {} {
  global filename linenumber type requirement SRCCAT SRCCLASS
  regsub -all {\s+} [string trim $requirement] { } requirement
  regsub -all {\s?\*/$} $requirement {} requirement
  if {![regexp {(R-[-\d]+)\s*(.*)} $requirement all reqno reqtext]} {
    return
  }
  if {[string range $reqtext 0 2]=="-- "} {set reqtext {}}
  if {$reqtext!=""} {
    set nreqno R-[md5-10x8 $reqtext]
    if {[string match $reqno* $nreqno]} {
      set reqno $nreqno
    } else {
      puts stderr "$filename:$linenumber: requirement number mismatch;\
                   $reqno should be $nreqno"
    }
  } elseif {[string length $reqno]<49} {
    db eval {
      SELECT reqno AS nreqno FROM requirement
       WHERE reqno>=$reqno
         AND reqno GLOB $reqno || '*'
    } {
      set reqno $nreqno
      break
    }
  }
  set fn [file tail $filename]
  db eval {
    REPLACE INTO evidence
          (reqno,  reqtext,  evtype, srcclass,  srccat,  srcfile, srcline)
    VALUES($reqno, $reqtext, $type,  $SRCCLASS, $SRCCAT, $fn,     $linenumber);
  }
  set linenumber 0
}

# Regular expression used to locate the beginning of an evidence mark.
#
set re {^\s*(/\*|\*\*|#) (EV|EVIDENCE-OF|IMP|IMPLEMENTATION-OF|ANALYSIS-OF): }

db transaction {
  if {$RESET} {
    db eval {DELETE FROM evidence}
  }
  foreach sourcefile $FILELIST {
    set filename $sourcefile
    set in [open $sourcefile]
    set lineno 0
    set linenumber 0
    while {![eof $in]} {
      incr lineno
      set line [gets $in]
      if {[regexp $re $line all mark tp]} {
        if {$linenumber>0} output_one_record
        set linenumber $lineno
        if {[string index $tp 0]=="E"} {
          set type evidence
        } else {
          set type implementation
        }
        regexp {[^:]+:\s+(.*)$} $line all requirement
        set requirement [string trim $requirement]
        continue
      }
      if {$linenumber>0} {
        if {[regexp {^\s*(\*\*|#)\s+([^\s].*)$} $line all commark tail]} {
          append requirement " [string trim $tail]"
          continue
        }
        output_one_record
      }
      if {[regexp {/\* (EV: |IMP: |)(R-\d[-\d]+\d) \*/} $line all tp rno]} {
        set linenumber $lineno
        if {$tp=="EV: "} {
          set type evidence
        } elseif {$tp=="IMP:"} {
          set type implementation
        } elseif {[regexp {assert\(} $line]} {
          set type assert
        } elseif {[regexp {testcase\(} $line]} {
          set type testcase
        } else {
          set type implementation
        }
        set requirement $rno
        output_one_record
      }
    }
    close $in
  }
}
