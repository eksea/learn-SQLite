

# Use the hdom.tcl module.
#
source [file join [file dirname [info script]] .. search hdom.tcl]

#-------------------------------------------------------------------------
# Return the HTML equivalent of the contents of node N (but not the
# node itself).
#
proc hdom_innerhtml {N} {
  set ret ""
  foreach c [$N children] {
    append ret [$c html]
  }
  set ret
}

proc addtoc {zDoc} {
  # If the extension with the [parsehtml] command has not been loaded,
  # load it now.
  #
  if {[info commands parsehtml] == ""} { load ./parsehtml.so }

  # Handle any <tclscript> blocks.
  #
  while { [regexp -nocase {<tclscript>(.*?)</tclscript>} $zDoc -> script] } {
    set sub [eval $script]
    set sub [string map {& {\&}} $sub]
    set zDoc [regsub -nocase {<tclscript>.*?</tclscript>} $zDoc $sub]
  }

  set bToc [string match *<table_of_contents>* $zDoc]
  set zDoc [string map [list <table_of_contents> "" <fancy_format> ""] $zDoc]

  # Parse the document into a DOM tree.
  #
  set dom [::hdom::parse $zDoc]
  set toc ""

  # Iterate through the document tree. For each heading, add a number to
  # the start of it and an entry to the table-of-contents. If the <h[12345]>
  # block does not already have an "id=" attribute, give it one.
  #
  set S(1) 0
  set S(2) 0
  set S(3) 0
  set S(4) 0
  set S(5) 0
  [$dom root] foreach_descendent N {
    set tag [$N tag]
    if {[string match {h[12345]} $tag]} {

      # Ensure that the heading has an id= attribute
      #
      if {[$N attr -default "" id] == ""} {
        set id ""
        foreach t [split [$N text] {}] {
          if {[string is alnum $t]} {
            append id [string tolower $t]
          } elseif {[string range $id end end]!="_"} {
            append id _
          }
        }
        $N attr id $id
      }

      if {[catch {$N attr notoc}]} {
        # Add a section number to the heading.
        #
        set n [string range $tag 1 end]
        if {[catch {$N attr nonumber}]} {
          incr S($n)
          set section_number ""
          for {set i 1} {$i<=$n} {incr i} { append section_number "$S($i)." }
          for {set i [expr $n+1]} {$i<=5} {incr i} { set S($i) 0 }
          set node [$dom parsenode "<span>$section_number </span>" ]
          $N addChild $node
        }
        
        # If there is a "tags" attribute, add an [hd_fragment] command to
        # the document. It will be processed by the wrap.tcl module.
        #
        set tags [$N attr -default "" tags]
        if {$tags != ""} {
          set T [
            $dom parsenode "<tcl>[list hd_fragment [$N attr id] $tags]</tcl>"
          ]
          [$N parent] addChild -before $N $T
        }
  
        # The TOC entry.
        #
        set    entry "<div class=\"fancy-toc$n\">"
        append entry   "<a href=\"#[$N attr id]\">[$N text]</a>"
        append entry "</div>"
        append toc "$entry\n"
      }
    }

    # Add the special formatting for a <codeblock> block.
    #
    if {$tag == "codeblock"} {
      catch { unset nMinSpace }
      set txt [string trim [hdom_innerhtml $N] "\n"]
      foreach line [split $txt "\n"] {
        if {![string is space $line]} {
          set nSpace [expr {
            [string length $line] - [string length [string trimleft $line]]
          }]
          if {[info exists nMinSpace]==0 || $nSpace<$nMinSpace} {
            set nMinSpace $nSpace
          }
        }
      }

      set pre ""
      foreach line [split $txt "\n"] {
        set line [string range $line $nMinSpace end]
        append pre "$line\n"
      }

      if {[$N attr -default "" class]=="C"} {
        set pre [string map [list /* <i>/* */ */</i>] $pre]
      }

      set new "<div class=codeblock><pre>$pre</pre></div>"
      set newnode [$dom parsenode $new]
      [$N parent] addChild -before $N $newnode
      $N detach
    }

    # Add alternating light and dark rows to <table striped> blocks.
    #
    if {$tag == "table" && [catch {$N attr striped}]==0} {
      $N attr style "margin:1em auto; width:80%; border-spacing:0"
      set stripe_toggle 1
    }
    if {$tag == "tr"} {
      for {set P [$N parent]} {$P!=""} {set P [$P parent]} {
        if {[$P tag]=="table"} {
          if {[catch {$P attr striped}]==0} {
            if {$stripe_toggle} {
              $N attr style "text-align:left"
              set stripe_toggle 0
            } else {
              $N attr style "text-align:left;background-color:#DDDDDD"
              set stripe_toggle 1
            }
          }
          break
        }
      }
    }
  }

  # Find the document title.
  #
  set title ""
  set T [lindex [[$dom root] search title] 0]
  if {$T!=""} { set title [$T text] }

  # Format the table of contents, if required.
  #
  set zToc ""
  if {$bToc} {
    set zToc [subst {
      <div class="fancy_toc">
        <a onclick="toggle_toc()">
        <span class="fancy_toc_mark" id="toc_mk">&#x25ba;</span>
        Table Of Contents
        </a>
        <div id="toc_sub">$toc</div>
      </div>
      <script>
        function toggle_toc(){
          var sub = document.getElementById("toc_sub")
          var mk = document.getElementById("toc_mk")
          if( sub.style.display!="block" ){
            sub.style.display = "block";
            mk.innerHTML = "&#x25bc;";
          } else {
            sub.style.display = "none";
            mk.innerHTML = "&#x25ba;";
          }
        }
      </script>
    }]
    regsub -all {\n\s+} $zToc "\n" zToc
  }

  # Format the document text to return.
  #
  set zRet [hd_trim [subst {
    <div class=fancy>
    <div class=nosearch>
      <div class="fancy_title">
        $title
      </div>
      $zToc
    </div>
  }]]\n
  append zRet [hdom_innerhtml [$dom root]]
  $dom destroy
  return $zRet
}
