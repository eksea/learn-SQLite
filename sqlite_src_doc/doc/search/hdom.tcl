
#-------------------------------------------------------------------------
#
# SUMMARY:
#
#    set doc [hdom parse HTML]
#
# DOCUMENT OBJECT API:
#
#    $doc root
#      Return the root node of the document.
#
#    $doc destroy
#      Destroy DOM object
#
#    $doc parsenode HTML
#      Parse return a new node or nodes.
#
# NODE OBJECT API:
#
#    $node tag
#      Get or set the nodes tag type. Always lower-case. Empty string 
#      for text.
#
#    $node children
#      Return a list of the nodes children.
#
#    $node text
#      For a text node, return the text. For any other node, return the
#      concatenation of the text belonging to all descendent text nodes
#      (in document order).
#
#    $node parent
#      Return the nodes parent node. 
#
#    $node offset
#      Return the byte offset of the node within the document (if any).
#
#    $node foreach_descendent VARNAME SCRIPT
#      Iterate through all nodes in the sub-tree headed by $node. $node 
#      itself is not visited.
#
#    $node attr ?-default VALUE? ATTR ?NEWVALUE?
#
#    $node search PATTERN
#      Return a list of descendent nodes that match pattern PATTERN.
#
#    $node addChild ?-before BEFORENODE? NEWNODE
#      Detach NEWNODE from its current parent and add it as the first
#      child of $node. Or, if the -before switch is specified, immediately
#      before BEFORENODE.
#
#    $node html
#      Return HTML code equivalent to the node.
#
#    $node detach
#      Detach $node from its parent.
#

catch { load ./parsehtml.so }

#-------------------------------------------------------------------------
# Throw an exception if the expression passed as the only argument does
# not evaluate to true.
#
proc assert {condition} {
  uplevel [list if "! ($condition)" [list error "assert failed: $condition"]]
}

#--------------------------------------------------------------------------
#
# A parsed HTML document tree is store in a single array object. Each node
# is stored in three array entries:
#
#   O($id,tag)      ("" for text, tag name for other nodes)
#   O($id,detail)   (text data for text, key-value attribute list for others)
#   O($id,children) (list of child ids)
#   O($id,parent)   (parent node id)
#   O($id,offset)   (byte offset within original document text)
#
# Each node is identified by its key in the array. The root node's key is
# stored in O(root). All nodes have automatically generated keys.
#
namespace eval hdom {
  variable iNextid 0

  # Ignore all tags in the aIgnore[] array.
  variable aIgnore
  set aIgnore(html) 1
  set aIgnore(/html) 1
  set aIgnore(!doctype) 1
  
  # All inline tags.
  variable aInline
  foreach x {
    tt i b big small u
    em strong dfn code samp kbd var cite abbr acronym
    a img object br script map q sub sup span bdo
    input select textarea label button tcl yyterm
  } { set aInline($x) 1 }

  # All self-closing tags (set below)
  variable aSelfClosing

  variable aContentChecker
  set aContentChecker(p)        HtmlInlineContent
  set aContentChecker(th)       HtmlTableCellContent
  set aContentChecker(td)       HtmlTableCellContent
  set aContentChecker(tr)       HtmlTableRowContent
  set aContentChecker(table)    HtmlTableContent
  set aContentChecker(a)        HtmlAnchorContent
  set aContentChecker(ul)       HtmlUlContent
  set aContentChecker(ol)       HtmlUlContent
  set aContentChecker(menu)     HtmlUlContent
  set aContentChecker(dir)      HtmlUlContent
  set aContentChecker(form)     HtmlFormContent
  set aContentChecker(option)   HtmlPcdataContent
  set aContentChecker(li)       HtmlLiContent
  set aContentChecker(dt)       HtmlLiContent
  set aContentChecker(dd)       HtmlLiContent
  set aContentChecker(dl)       HtmlDlContent

  # Add content checkers for all self-closing tags.
  foreach x {
    area base br hr iframe img input isindex link meta 
    param script style embed nextid wbr bgsound
  } { 
    set aContentChecker($x) HtmlEmptyContent 
    set aSelfClosing($x) 1
  }

  namespace export parse
  namespace ensemble create
}

proc ::hdom::nextNodeId {} {
  variable iNextid
  set res "::hdom::node_$iNextid"
  incr iNextid
  return $res
}

proc ::hdom::nextDocId {} {
  variable iNextid
  set res "::hdom::doc_$iNextid"
  incr iNextid
  return $res
}

# Return "close" if the content is not Ok. Or "parent" if it is ok, but the
# caller should check the parent. Or "ok" if is unconditionally Ok.
#
proc ::hdom::HtmlInlineContent {tag} {
  variable aInline
  if {$tag == ""} { return "ok" }
  if {[info exists aInline($tag)]} { return "parent" }
  return "close"
}
proc ::hdom::HtmlEmptyContent {tag} {
  return "close"
}
proc ::hdom::HtmlTableCellContent {tag} {
  if {$tag == "th" || $tag == "td" || $tag == "tr"} { return "close" }
  return "parent"
}
proc ::hdom::HtmlTableRowContent {tag} {
  if {$tag == "tr"} { return "close" }
  return "parent"
}
proc ::hdom::HtmlTableContent {tag} {
  if {$tag == "table"} { return "close" }
  return "ok"
}
proc ::hdom::HtmlLiContent {tag} {
  if {$tag == ""} { return "ok" }
  if {$tag == "li" || $tag=="dd" || $tag=="dt"} { return "close" }
  return "parent"
}
proc ::hdom::HtmlAnchorContent {tag} {
  if {$tag == ""} { return "ok" }
  if {$tag == "a"} { return "close" }
  return "parent"
}
proc ::hdom::HtmlUlContent {tag} {
  if {$tag == "" || $tag=="li"} { return "ok" }
  return "parent"
}
proc ::hdom::HtmlDlContent {tag} {
  if {$tag == "dd" || $tag=="dt" || $tag==""} { return "ok" }
  return "parent"
}
proc ::hdom::HtmlFormContent {tag} {
  if {$tag == "tr" || $tag=="td" || $tag=="th"} { return "close" }
  return "parent"
}
proc ::hdom::HtmlPcdataContent {tag} {
  if {$tag == ""} { return "parent" }
  return "close"
}

proc ::hdom::parsehtml_cb {arrayname tag detail offset endoffset} {
  variable aIgnore
  variable aContentChecker

  upvar $arrayname O

  # Fold the tag name to lower-case.
  set tag [string tolower $tag]

  # Ignore <html> and </html> tags.
  if {[info exists aIgnore($tag)]} return

  # An explicit close tag. Search for a tag to close.
  if { [string range $tag 0 0]=="/" } {
    set match [string range $tag 1 end]
    for {set id $O(current)} {$id!=""} {set id $O($id,parent)} {
      if {$O($id,tag)==$match} break
    }

    # The closing tag matches node $id. So the new current node is its parent.
    if {$id!=""} {
      assert {$id!=$O(root)}
      set O(current) $O($id,parent)
    }

    return
  }

  # Check for implicit close tags.
  if {$tag!=""} {
    for {set id $O(current)} {$id!=""} {set id $O($id,parent)} {
      set ptag $O($id,tag)
      if { [info exists aContentChecker($ptag)] } {
        switch -- [$aContentChecker($ptag) $tag] {
          "parent" {
            # no-op
          }

          "close" {
            # Close tag $id
            assert {$id!=$O(root)}
            set O(current) $O($id,parent)
          }

          "ok" {
            # Break out of the for(...) loop
            break
          }

          default {
            error "content checker $aContentChecker($ptag) failed"
          }
        }
      }
    }
  }

  # Add the new node to the database.
  set newid [nextNodeId]
  set O($newid,tag) $tag
  set O($newid,detail) $detail
  set O($newid,children) [list]
  set O($newid,parent) $O(current)
  set O($newid,offset) $offset

  # Link it into its parent's child array.
  lappend O($O(current),children) $newid

  if {$tag != ""} {
    set O(current) $newid
  }
}

# Node method [$node tag]
#
proc ::hdom::nm_tag {arrayname id} {
  upvar $arrayname O
  return $O($id,tag)
}

# Node method [$node parent]
#
proc ::hdom::nm_parent {arrayname id} {
  upvar $arrayname O
  return [create_node_command $arrayname $O($id,parent)]
}

# Node method [$node children]
#
proc ::hdom::nm_children {arrayname id} {
  upvar $arrayname O
  foreach c $O($id,children) { create_node_command $arrayname $c }
  return $O($id,children)
}

proc ::hdom::foreach_desc {arrayname id varname script level} {
  upvar $arrayname O
  foreach c $O($id,children) { 
    create_node_command $arrayname $c
    uplevel $level [list set $varname $c]

    set rc [catch { uplevel $level $script } msg info]
    if {$rc == 0 || $rc == 4} {
      # TCL_OK or TCL_CONTINUE Do nothing
    } elseif {$rc == 3} {
      # TCL_BREAK
      return 1
    } else {
      # TCL_RETURN or TCL_ERROR.
      return -options $info
    }

    if {[foreach_desc $arrayname $c $varname $script [expr $level+1]]} {
      return 1
    }
  }

  return 0
}

# Node method [$node foreach_descendent]
#
proc ::hdom::nm_foreach_descendent {arrayname id varname script} {
  foreach_desc $arrayname $id $varname $script 2
  return ""
}

# Node method [$node text]
#
proc ::hdom::nm_text {arrayname id} {
  upvar $arrayname O
  if { $O($id,tag)=="" } {
    return $O($id,detail)
  }

  set ret ""
  $id foreach_descendent N {
    if {[$N tag] == ""} { append ret [$N text] }
  }
  return $ret
}

# Node method [$node offset]
#
proc ::hdom::nm_offset {arrayname id} {
  upvar $arrayname O
  return $O($id,offset)
}

# Node method: $node attr ?-default VALUE? ?ATTR? 
#
#   $node attr
#   $node attr ATTR
#   $node attr ATTR NEWVALUE
#   $node attr -default VALUE ATTR
#
proc ::hdom::nm_attr {arrayname id args} {
  upvar $arrayname O

  set dict $O($id,detail)
  if {[llength $args]==0} { return $dict }
  if {[llength $args]==1} {
    set nm [lindex $args 0]
    if {[catch { set res [dict get $dict $nm] }]} {
      error "no such attribute: $nm"
    }
  }
  if {[llength $args]==3} {
    if {[lindex $args 0] != "-default"} {
      error "expected \"-default\" got \"[lindex $args 0]\""
    }
    set nm [lindex $args 2]
    if {[catch { set res [dict get $dict $nm] }]} {
      set res [lindex $args 1]
    }
  }
  if {[llength $args]==2} {
    set res [lindex $args 1]
    dict set O($id,detail) [lindex $args 0] $res
  }

  return $res
}

proc ::hdom::nodematches {N pattern} {
  set tag [$N tag]
  if {[string compare $pattern $tag]==0} {
    return 1
  }
  return 0
}

# Node method: $node search PATTERN
#
proc ::hdom::nm_search {arrayname id pattern} {
  set ret [list]
  $id foreach_descendent N {
    if {[::hdom::nodematches $N $pattern]} {
      lappend ret $N
    }
  }
  set ret
}

# Node method: $node html
#
proc ::hdom::nm_html {arrayname id} {
  variable aSelfClosing
  set res ""

  set tag [$id tag]
  if {$tag ==""} {
    append res [$id text]
  } else {
    append res "<$tag"
    foreach {k v} [$id attr] { append res " $k=\"$v\"" }
    append res ">"
    foreach N [$id children] {
      append res [$N html]
    }

    if { [info exists aSelfClosing($tag)]==0 } {
      append res "</$tag>"
    }
  }

  set res
}

# Node method: $node detach
#
proc ::hdom::nm_detach {arrayname id} {
  upvar $arrayname O

  set P $O($id,parent)
  if {$P!=""} {
    set idx [lsearch $O($P,children) $id]
    if {$idx<0} {error "internal error!"}
    set O($P,children) [lreplace $O($P,children) $idx $idx]
  }
}

# Node method: 
#
#   $node addChild CHILD
#   $node addChild -before BEFORE CHILD
#
proc ::hdom::nm_addChild {arrayname id args} {
  upvar $arrayname O

  if {[llength $args]==1} {
    set newidx 0
    set newchild [lindex $args 0]
  } elseif {[llength $args]==3} {
    if {[lindex $args 0] != "-before"} {
      error "expected \"-before\" got \"[lindex $args 0]\""
    }
    set before [lindex $args 1]
    set newidx [lsearch $O($id,children) $before]
    if {$newidx < 0 } {error "$before is not a child of $id"}
    set newchild [lindex $args 2]
  }

  # Unlink $newchild from its parent:
  $newchild detach
   
  # Link $newchild to new parent ($id):
  set O($id,children) [linsert $O($id,children) $newidx $newchild]
  set O($newchild,parent) $id
}

# Document method [$doc root]
#
proc ::hdom::dm_root {arrayname} {
  upvar $arrayname O
  return [create_node_command $arrayname $O(root)]
}

# Document method [$doc destroy]
#
proc ::hdom::dm_destroy {arrayname} {
  upvar $arrayname O
  proc $arrayname {method args} {}
  foreach cmd $O(cmdlist) { proc $cmd {methods args} {} }
  catch { uplevel [list array unset $arrayname ] }
}

# Document method [$doc parsenode]
#
proc ::hdom::dm_parsenode {arrayname html} {
  upvar $arrayname O

  set current ""

  set O($current,tag) html
  set O($current,children) [list]
  set O($current,parent) ""
  set O($current,detail) ""
  set O($current,offset) 0
  set O(current) $current

  parsehtml $html [list parsehtml_cb $arrayname]
  set res $O($current,children)

  unset O($current,tag)
  unset O($current,children)
  unset O($current,parent)
  unset O($current,detail)
  unset O($current,offset)

  foreach id $res { create_node_command $arrayname $id }

  return $res
}

proc ::hdom::node_method {arrayname id method args} {
  uplevel ::hdom::nm_$method $arrayname $id $args
}
proc ::hdom::document_method {arrayname method args} {
  uplevel ::hdom::dm_$method $arrayname $args
}

# Return the name of the command for node $id, part of document $arrayname.
#
proc ::hdom::create_node_command {arrayname id} {
  upvar $arrayname O
  if { [llength [info commands $id]]==0} {
    proc $id {method args} [subst -nocommands {
      uplevel ::hdom::node_method $arrayname $id [set method] [set args]
    }]
    lappend O(cmdlist) $id
  }
  return $id
}

# Parse the html document passed as the first argument.
#
proc ::hdom::parse {html} {
  set doc [nextDocId]
  variable $doc
  upvar 0 $doc O
  set root [nextNodeId]

  # Add the root node to the tree.
  #
  set O($root,tag) html
  set O($root,detail) [list]
  set O($root,children) [list]
  set O($root,parent) ""

  # Setup the other state data for the parse.
  #
  set O(current) $root
  set O(root) $root
  set O(cmdlist) [list]

  parsehtml $html [list parsehtml_cb O]

  # Create the document object command. 
  #
  proc $doc {method args} [subst -nocommands {
    uplevel ::hdom::document_method $doc [set method] [set args]
  }]
  return $doc
}
