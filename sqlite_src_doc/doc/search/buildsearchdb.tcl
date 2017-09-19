

#load ./parsehtml.so
#load ./tokenize.so

source [file join [file dirname [info script]] hdom.tcl]

set ::G(rowid) 1

proc releaselog_to_version {doc} {
  set version 0_0_0
  regexp {releaselog/(.*).html} $doc -> version
  split $version _
}

proc release_cmp {a b} {
  set v1 [releaselog_to_version $a]
  set v2 [releaselog_to_version $b]
  lappend v1 {*}[lrange {-1 -1 -1 -1 -1} [llength $v1] end]
  lappend v2 {*}[lrange {-1 -1 -1 -1 -1} [llength $v2] end]
  foreach x $v1 y $v2 {
    if {$x < $y} { return -1 }
    if {$x > $y} { return +1 }
  }
  return 0
}

# Return a list of relative paths to documents that should be included 
# in the index.
proc document_list {type} {
  global weight
  set lFiles [list]
  switch -- $type {
    lang {
      foreach f [glob lang_*.html] { lappend lFiles $f }
    }

    c3ref {
      set blacklist(objlist.html) 1
      set blacklist(constlist.html) 1
      set blacklist(funclist.html) 1

      lappend lFiles c3ref/free.html
      lappend lFiles c3ref/exec.html
      lappend lFiles c3ref/mprintf.html
      lappend lFiles c3ref/io_methods.html

      foreach f [glob c3ref/*.html] { 
        if {[info exists blacklist([file tail $f])]} continue
        if {[lsearch $lFiles $f]<0} { lappend lFiles $f }
      }
    }

    generic {
      set nosearch(doc_keyword_crossref.html) 1
      set nosearch(doc_backlink_crossref.html) 1
      set nosearch(doc_pagelink_crossref.html) 1
      set nosearch(doc_target_crossref.html) 1
      set nosearch(doclist.html) 1
      set nosearch(keyword_index.html) 1
      set nosearch(requirements.html) 1
      set nosearch(sitemap.html) 1
      set nosearch(fileio.html) 1
      set nosearch(btreemodule.html) 1
      set nosearch(capi3ref.html) 1
      set nosearch(changes.html) 1
      set nosearch(fileformat2.html) 1
      set nosearch(index.html) 1
      set nosearch(docs.html) 1
      set nosearch(mingw.html) 1

      set weight(chronology.html) 25

      foreach f [glob *.html] { 
        if {[string match lang_* $f]==0 && [info exists nosearch($f)]==0} {
          lappend lFiles $f 
        }
      }

      # "current.html" is a duplicate of the most recent release. Don't
      # index it at all.
      set nosearch(releaselog/current.html) 1


      # As of version 3.7.16, sub-release changelogs duplicated the entries
      # from the major release. This block does the following:
      #
      #   * sets the weight of a changelog containing superceded content
      #     to 10%
      #   * sets the weights of other changelogs to 25%.
      #
      foreach f [glob releaselog/*.html] { 
        set tail [file tail $f]
        set ::weight($f) 25
        if {[regexp {^(3_8_[0-9]*).*} $tail -> prefix]
         || [regexp {^(3_7_16).*} $tail -> prefix]
         || [regexp {^(3_9_).*} $tail -> prefix]
         || [regexp {^(3_[1-9][0-9]).*} $tail -> prefix]
        } {
          set f1 [lindex [lsort -decreasing [glob releaselog/$prefix*.html]] 0]
          if {$f!=$f1} { set ::weight($f) 10 }
        } 
      }
    }

    changelog {
      foreach f [lsort -decr -command release_cmp [glob releaselog/*.html]] { 
        if {$f != "releaselog/current.html"} { lappend lFiles $f }
      }
    }

    default {
      error "document_list: unknown file type $type"
    }
  }
  return $lFiles
}

proc readfile {zFile} {
  set fd [open $zFile]
  set ret [read $fd]
  close $fd
  return $ret
}

# Insert a new entry into the main "page" table of the search database.
# Values are determined by switches passed to this function:
#
#   -apis      List of APIs
#   -rowid     Rowid to use
#   -title1    Document title
#   -title2    Heading title (or NULL)
#   -content   Document content
#   -url       URL of this document
#
# Return the rowid of the row just inserted into the table.
# 
proc insert_entry {args} {
  global G
  if {[llength $args] % 2} { error "Bad arguments passed to insert_entry (1)" }

  set switches {
    -apis -title1 -title2 -content -url -keywords -rowid
  }
  set V(content) ""

  foreach {k v} $args {
    set idx [lsearch -all $switches $k*] 
    if {[llength $idx]!=1} { error "Bad switch passed to insert_entry: $k" }
    set V([string range [lindex $switches $idx] 1 end]) $v
  }
  
  set V(content) [string trim $V(content)]
  if {[info exists V(rowid)]==0} {
    set V(rowid) [incr G(rowid)];
  }

  db eval {
    INSERT INTO page(rowid, apis, keywords, title1, title2, content, url) 
    VALUES($V(rowid),
        $V(apis), $V(keywords), $V(title1), $V(title2), $V(content), $V(url)
    );
  }

  return [db last_insert_rowid]
}

# Extract a document title from DOM object $dom passed as the first
# argument. If no <title> node can be found in the DOM, use $fallback
# as the title.
#
proc extract_title {dom fallback} {
  set title_node [lindex [[$dom root] search title] 0]
  if {$title_node==""} {
    set title $fallback
  } else {
    set title [$title_node text]
  }

  set title
}

proc c3ref_document_apis {dom} {
  global c3ref_blacklist

  set res [list]
  foreach N [[$dom root] search blockquote] {
    set text [$N text]
    while {[regexp {(sqlite3[0-9a-z_]*) *\((.*)} $text -> api text]} {
      if {[info exists c3ref_blacklist($api)]==0} {
        lappend res "${api}()"
        set c3ref_blacklist($api) 1
      }
    }

    set text [$N text]
    set pattern {struct +(sqlite3[0-9a-z_]*)(.*)}
    while {[regexp $pattern $text -> api text]} {
      if {[info exists c3ref_blacklist($api)]==0} {
        lappend res "struct ${api}"
        set c3ref_blacklist($api) 1
      }
    }

    set text [$N text]
    set pattern {#define +(SQLITE_[0-9A-Z_]*)(.*)}
    while {[regexp $pattern $text -> api text]} {
      if {[info exists c3ref_blacklist($api)]==0} {
        lappend res "${api}"
        set c3ref_blacklist($api) 1
      }
    }
  }

  return [join $res ", "]
}

proc c3ref_filterscript {N} {
  for {set P [$N parent]} {$P!=""} {set P [$P parent]} {
    if {[$P attr -default "" class]=="nosearch"} { return 0 }
    if {[$P tag]=="blockquote" } { return 0 }
  }
  return 1
}

proc lang_filterscript {N} {
  for {set P [$N parent]} {$P!=""} {set P [$P parent]} {
    if {[$P attr -default "" class]=="nosearch"} { return 0 }
    if {[$P tag]=="button" } { return 0 }
    if {[$P tag]=="a" && [string match syntax/* [$P attr -default "" href]] } {
      return 0
    }
  }
  return 1
}

proc generic_filterscript {N} {
  for {set P [$N parent]} {$P!=""} {set P [$P parent]} {
    if {[$P attr -default "" class]=="nosearch"} { return 0 }
  }
  return 1
}

proc releaselog_filterscript {N} {
  for {set P [$N parent]} {$P!=""} {set P [$P parent]} {
    if {[$P attr -default "" class]=="nosearch"} { return 0 }
    if {[$P tag]=="li"} { return 0 }
  }
  return 1
}

proc extract_text_from_dom {dom filterscript} {
  set text ""
  set body [lindex [[$dom root] search body] 0]
  $body foreach_descendent N {
    if {[$N tag]==""} {
      if {[eval $filterscript $N]} { append text [$N text] }
    }
  }
  return $text
}

proc get_node_id {N {default ""}} {
  $N attr -default [$N attr -default $default _id] id
}

proc extract_sections_from_dom {dom filterscript} {
  set body [lindex [[$dom root] search body] 0]

  set h(h) 1
  set h(h1) 1
  set h(h2) 1
  set h(h3) 1

  set res [list]

  $body foreach_descendent N {
    set tag [$N tag]
    if {[eval $filterscript $N]==0} continue

    if {[info exists h($tag)]} {
      set id [get_node_id $N]
      if {$id != ""} {
        if {[info exists H]} {
          lappend res [list [get_node_id $H] [$H text] $content]
        } else {
          lappend res [list "" "" $content]
        }
        set H $N
        set content ""
      }
    }

    if {$tag==""} {
      if {[info exists H]} {
        for {set P [$N parent]} {$P!=""} {set P [$P parent]} {
          if {$P==$H} break
        }
        if {$P==""} { append content [$N text] }
      } else {
        append content [$N text]
      }
    }
  }

  if {[info exists H]} {
    lappend res [list [get_node_id $H] [$H text] $content]
    return $res
  }
  return ""
}

proc lang_document_import {doc} {
  set dom [::hdom::parse [readfile $doc]]

  # Find the <title> tag and extract the title.
  set title [extract_title $dom $doc]

  # Extract the entire document text.
  set text [extract_text_from_dom $dom lang_filterscript]

  # Insert into the database.
  insert_entry -url $doc -title1 $title -content $text

  $dom destroy
}

proc c3ref_document_import {doc} {
  set dom [::hdom::parse [readfile $doc]]
  
  # Find the <title> tag and extract the title.
  set title [extract_title $dom $doc]
  set title "C API: $title"

  set text [extract_text_from_dom $dom c3ref_filterscript]
  set apis [c3ref_document_apis $dom]

  # Insert into the database.
  insert_entry -url $doc -apis $apis -title1 $title -content $text
}

proc generic_document_import {doc} {
  set dom [::hdom::parse [readfile $doc]]
  
  # Find the <title> tag and extract the title.
  set title [extract_title $dom $doc]

  # Extract the document text
  set text [extract_text_from_dom $dom generic_filterscript]

  # Insert into the database.
  set rowid [insert_entry -url $doc -title1 $title -content $text]

  # Find any sections within the document
  set lSection [extract_sections_from_dom $dom generic_filterscript]

  set i [expr $rowid*1000]
  foreach section $lSection {
    foreach { tag hdr text } $section {}
    if {[string trim $text]==""} continue
    incr i
    set url "${doc}#${tag}"
    insert_entry -rowid $i -url $url -title1 $title -title2 $hdr -content $text
  }
}

proc node_innerhtml {n} {
  set ret ""
  foreach c [$n children] { append ret [$c html] }
  set ret
}

proc changelog_document_import {doc} {

  set content [readfile $doc]
  set end [string first "Changes carried forward from version " $content]
  if {$end>0} { set content [string range $content 0 $end] }

  set dom [::hdom::parse $content]

  foreach n [[$dom root] search p] {
    set c [lindex [$n children] 0]
    if {$c!="" && [$c tag]=="b"} { $n detach }
  }

  # Extract the version number from the document name.
  set version 0.0.0
  regexp {releaselog/(.*).html} $doc -> version
  set version [string map {_ .} $version]

  # Find each of the <li> nodes in the document.
  foreach li [[$dom root] search li] {
    if {0==[releaselog_filterscript $li]} continue

    set i 1
    set ol [$li parent]
    if {$ol=="" || [$ol tag]!="ol"} {error UNTHINKABLE!}
    foreach c [$ol children] {
      if {$c==$li} break
      if {[$c tag]=="li"} {incr i}
    }

    #set t [$li text]
    set t [node_innerhtml $li]
    db eval { INSERT INTO change VALUES($doc, $version, $i, $t) }
  }
}

proc rebuild_database {} {

  db transaction {
    # Create the database schema. If the schema already exists, then those
    # tables that contain document data are dropped and recreated by this
    # proc. The 'config' table is left untouched.
    #
    db eval {
      DROP TABLE IF EXISTS page;
      CREATE VIRTUAL TABLE page USING fts5(
        apis,                               -- C APIs 
        keywords,                           -- Keywords
        title1,                             -- Document title
        title2,                             -- Heading title, if any
        content,                            -- Document text

        url UNINDEXED,                      -- Indexed URL
        tokenize='stoken unicode61 tokenchars _' -- Tokenizer definition
      );

      DROP TABLE IF EXISTS weight;
      CREATE TABLE weight(id INTEGER PRIMARY KEY, percent FLOAT);

      INSERT INTO page(page, rank) VALUES('rank', 'bm25(10.0,10.0,20.0,20.0)');

      DROP TABLE IF EXISTS change;
      CREATE VIRTUAL TABLE change USING fts5(
          url UNINDEXED,          -- Path to document
          version UNINDEXED,      -- SQLite version number
          idx UNINDEXED,          -- Bullet point number
          text,                   -- Text of change log entry
          tokenize='html stoken unicode61 tokenchars _' -- Tokenizer definition
      );
    }

    foreach doc [document_list changelog] { 
      puts "Indexing $doc..."
      changelog_document_import $doc 
    }

    foreach doc [document_list lang] {
      puts "Indexing $doc..."
      lang_document_import $doc
    }

    foreach doc [document_list c3ref] {
      puts "Indexing $doc..."
      c3ref_document_import $doc
    }

    foreach doc [document_list generic] { 
      puts "Indexing $doc..."
      generic_document_import $doc 
    }


    db eval { INSERT INTO page(page) VALUES('optimize') }
    db eval { INSERT INTO change(change) VALUES('optimize') }

    foreach f [array names ::weight] {
      set w $::weight($f)
      db eval {SELECT rowid FROM page WHERE url=$f} {
        db eval { INSERT INTO weight VALUES($rowid, $w); }
      }
    }
  }

  db eval VACUUM
}

cd doc
sqlite3 db search.d/search.db
rebuild_database
