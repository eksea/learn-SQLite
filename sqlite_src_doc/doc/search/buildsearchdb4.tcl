
load ./parsehtml.so

#=========================================================================
# Return a list of relative paths to documents that should be included 
# in the index.
#
proc document_list {} {
  set files [list]
  foreach f [glob *.html c3ref/*.html releaselog/*.html] {
    if {![string match *crossref* $f]
     && ![string match fileio.html $f]
     && ![string match capi3ref.html $f]
     && ![string match changes.html $f]
     && ![string match btreemodule.html $f]
    } { lappend files $f }
  }
  return $files
}

#=========================================================================
# Read and return the contents of text file $zFile.
#
proc readfile {zFile} {
  set fd [open $zFile]
  set ret [read $fd]
  close $fd
  return $ret
}

#=========================================================================
# [parsehtml] callback used for parsing keywords.html...
#
proc keywordparse_callback {tag details} {
  global K P
  switch -- [string tolower $tag] {
    "" {
      if {[info exists K(hyperlink)]} {
        append K($K(hyperlink)) $details
      }
    }
    "a" {
      array set D $details
      if {[info exists D(href)]} { set K(hyperlink) $D(href) }
    }
    "/a" {
      unset -nocomplain P(hyperlink)
    }
  }
}

#=========================================================================
# This function is used as the callback when parsing ordinary documents 
# (not the keywords document).
#
# Rules for extracting fragment "titles". A fragment title consists of
# all text that follows the tag that opens the fragment until either:
#
#   1. 80 characters have been parsed, or
#   2. 8 characters have been parsed and one of the following is 
#        encountered:
#      a) A block element opening or closing tag, or
#      b) A <br> element, or
#      c) A "." character.
#
#   3. 8 characters have been parsed and a <br> tag or "." character is
#      encountered
#
proc docparse_callback {tag details} {
  global P
  set tag [string tolower $tag]
  switch -glob -- $tag {
    "" {
      append P(text) " $details"
      if {$P(isTitle)} { append P(title) $details }
      if {[llength $P(fragments)]} { 
        append P(ftext) " $details" 
      }
    }

    "title"  { set P(isTitle) 1 }
    "/title" { set P(isTitle) 0 }

    "a" { 
      array set D $details
      if {[info exists D(name)]} {
        if {[llength $P(fragments)]} { 
          lappend P(fragments) $P(ftitle) $P(ftext) 
        }
        lappend P(fragments) $D(name)
        set P(ftext) ""
        set P(ftitle) ""
        catch { unset P(ftitleclose) }
      }
    }
    "h*" {
      array set D $details
      if {[info exists D(id)]} {
        if {[llength $P(fragments)]} { 
          lappend P(fragments) $P(ftitle) $P(ftext) 
        }
        lappend P(fragments) $D(id)
        set P(ftext) ""
        set P(ftitle) ""
      }
    }

    div {
      array set D $details
      if {[info exists D(class)] && $D(class) == "startsearch"} { 
        set P(text) "" 
      }
    }
  }

  set ftext [string trim $P(ftext) " \v\n"]
  if {[string length $ftext]>4 && $P(ftitle) == ""} {
    set blocktags [list                               \
      br td /td th /th p /p                           \
      h1 h2 h3 h4 h5 h /h1 /h2 /h3 /h4 /h5 /h
    ]
    if {[lsearch $blocktags $tag]>=0} {
      set P(ftitle) $ftext
      set P(ftext)  ""
    } elseif {[string length $ftext]>80} {
      set idx [string last " " [string range $ftext 0 79]]
      if {$idx<0} { set idx 80 }
      set P(ftitle) [string range $ftext 0 [expr $idx-1]]
      set P(ftext)  [string range $ftext $idx end]
    } 
  }
}

proc findlinks_callback {tag details} {
  global P
  set doc $P(doc)

  set tag [string tolower $tag]
  switch -glob -- $tag {
    a {
      array set D $details
      if {[info exists D(href)]} {
        if { [string range $D(href) 0 0]=="#" } {
          set url "${doc}$D(href)"
        } else {
          set url "$D(href)"
        }

        set P(url) $url
        set P(link) ""
      }
    }
    /a {
      if {$P(url)!=""} {
        db eval { UPDATE pagedata SET links = links || ' ' || $P(link) WHERE url=$P(url) }
      }
      set P(url) ""
      set P(link) ""
    }

    "" {
      append P(link) " $details"
    }
  }
}

proc trim {a} {
  set L [split $a]
  return [lsort -uniq $L]
}

#=========================================================================
# Build the database.
#
proc rebuild_database {} {

  db transaction {
    db eval {
      DROP TABLE IF EXISTS pagedata;
      CREATE TABLE pagedata(
        url TEXT PRIMARY KEY,     -- Relative URL for this document
        links,                    -- Text of all links to this URI
        title,                    -- Document or fragment title
        content                   -- Document or fragment content
      );
    }

    # Scan the file-system for HTML documents. Add each document found to
    # the page and pagedata tables.
    foreach file [document_list] {
      set zHtml [readfile $file]

      array unset ::P
      set ::P(text) ""                 ;# The full document text
      set ::P(isTitle) 0               ;# True while parsing contents of <title>
      set ::P(fragments) [list]        ;# List of document fragments parsed
      set ::P(ftext) ""                ;# Text of current document fragment 

      parsehtml $zHtml docparse_callback
      if {[info exists ::P(ftitle)]} {
        lappend ::P(fragments) $::P(ftitle) $::P(ftext)
      }

      set keyword ""
      catch { set keyword $::K($file) }
      if {![info exists ::P(title)]} {set ::P(title) "No Title"}
      db eval { REPLACE INTO pagedata VALUES($file, '', $::P(title), $::P(text)) }

      foreach {name title text} $::P(fragments) {
        set url "$file#$name"
        puts $url
        db eval { REPLACE INTO pagedata VALUES($url, '', $title, $text) }
      }
    }

    foreach file [document_list] {
      set zHtml [readfile $file]

      array unset ::P
      set ::P(url) ""
      set ::P(doc) $file
      parsehtml $zHtml findlinks_callback
    }

    db func trim trim
    #db eval { UPDATE pagedata SET links = trim(links) }
    db eval { CREATE INDEX ft ON pagedata USING fts5() }
  }
}

sqlite4 db search4.db
rebuild_database

