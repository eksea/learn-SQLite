heading {Document Lists And Indexes} lists

doc {Alphabetical Listing Of All Documents} {doclist.html} {}
doc {Website Keyword Index} {keyword_index.html} {}
doc {Permuted Title Index} {sitemap.html#pindex} {}

###############################################################################
heading {Overview Documents} overview

doc {About SQLite} {about.html} {
  A high-level overview of what SQLite is and why you might be
  interested in using it.
}

doc {Appropriate Uses For SQLite} {whentouse.html} {
  This document describes situations where SQLite is an appropriate
  database engine to use versus situations where a client/server
  database engine might be a better choice.
}
doc {Distinctive Features} {different.html} {
  This document enumerates and describes some of the features of
  SQLite that make it different from other SQL database engines.
}
doc {How SQLite Is Tested} {testing.html} {
  The reliability and robustness of SQLite is achieved in large part
  by thorough and careful testing.  This document identifies the
  many tests that occur before every release of SQLite.
}
doc {Copyright} {copyright.html} {
  SQLite is in the public domain.  This document describes what that means
  and the implications for contributors.
}
doc {Frequently Asked Questions} {faq.html} {
  The title of the document says all...
}
doc {Books About SQLite} {books.html} {
  A list of independently written books about SQLite.
}



###############################################################################
heading {Programming Interfaces} programming {
  Documentation describing the APIs used to program SQLite, and the SQL
  dialect that it interprets.
}

doc {SQLite In 5 Minutes Or Less} {quickstart.html} {
  A very quick introduction to programming with SQLite.
}
doc {Introduction to the C/C++ API } {cintro.html} {
  This document introduces the C/C++ API. Users should read this document 
  before the C/C++ API Reference Guide linked below.
}
doc {How To Compile SQLite} {howtocompile.html} {
  Instructions and hints for compiling SQLite C code and integrating
  that code with your own application.
}
doc {C/C++ API Reference} {c3ref/intro.html} {
  This document describes each API function separately.
}
doc {Result and Error Codes} {rescode.html} {
  A description of the meanings of the numeric result codes
  returned by various C/C++ interfaces.
}
doc {SQL Syntax} {lang.html} {
  This document describes the SQL language that is understood by
  SQLite.  
}
doc {Pragma commands} {pragma.html} {
  This document describes SQLite performance tuning options and other 
  special purpose database commands.
}
doc {Core SQL Functions} {lang_corefunc.html} {
  General-purpose built-in scalar SQL functions.
}
doc {Aggregate SQL Functions} {lang_aggfunc.html} {
  General-purpose built-in aggregate SQL functions.
}
doc {Date and Time SQL Functions} {lang_datefunc.html} {
  SQL functions for manipulating dates and times.
}
doc {System.Data.SQLite} {http://system.data.sqlite.org/} {
  C#/.NET bindings for SQLite
}
doc {Tcl API} {tclsqlite.html} {
  A description of the TCL interface bindings for SQLite.
}
doc {DataTypes} {datatype3.html} {
  SQLite version 3 introduces the concept of manifest typing, where the
  type of a value is associated with the value itself, not the column that
  it is stored in.
  This page describes data typing for SQLite version 3 in further detail.
}

###############################################################################
heading {Extensions} extensions {
}
doc {Json1 - JSON Integration} {json1.html} {
  SQL functions for creating, parsing, and querying JSON content.
}
doc {FTS5 - Full Text Search} {fts5.html} {
  A description of the SQLite Full Text Search (FTS5) extension.
}
doc {FTS3 - Full Text Search} {fts3.html} {
  A description of the SQLite Full Text Search (FTS3) extension.
}
doc {R-Tree Module} {rtree.html} {
  A description of the SQLite R-Tree extension. An R-Tree is a specialized
  data structure that supports fast multi-dimensional range queries often
  used in geospatial systems.
}
doc {Sessions} {sessionintro.html} {
  The Sessions extension allows change to an SQLite database to be
  captured in a compact file which can be reverted on the original
  database (to implement "undo") or transferred and applied to another
  similar database.
}
doc {Run-Time Loadable Extensions} {loadext.html} {
  A general overview on how run-time loadable extensions work, how they
  are compiled, and how developers can create their own run-time loadable
  extensions for SQLite.
}
doc {SQLite Android Bindings} {http://sqlite.org/android/} {
  Information on how to deploy your own private copy of SQLite on
  Android, bypassing the built-in SQLite, but using the same Java
  interface.
}
doc {Dbstat Virtual Table} {dbstat.html} {
  The DBSTAT virtual table reports on the sizes and geometries of tables
  storing content in an SQLite database, and is the basis for the
  [sqlite3_analyzer] utility program.
}
doc {Csv Virtual Table} {csv.html} {
  The CSV virtual table allows SQLite to directly read and query
  [https://www.ietf.org/rfc/rfc4180.txt|RFC 4180] formatted files.
}
doc {Carray} {carray.html} {
  CARRAY is a [table-valued function] that allows C-language arrays to
  be used in SQL queries.
}
doc {generate_series} {series.html} {
  A description of the generate_series() [table-valued function].
}
doc {Spellfix1} {spellfix1.html} {
  The spellfix1 extension is an experiment in doing spelling correction
  for [full-text search].
}

###############################################################################
heading {Features} features {
  Pages describing specific features or extension modules of SQLite.
}
doc {8+3 Filenames} {shortnames.html} {
  How to make SQLite work on filesystems that only support 
  8+3 filenames.
}
doc {Autoincrement} {autoinc.html} {
  A description of the AUTOINCREMENT keyword in SQLite, what it does,
  why it is sometimes useful, and why it should be avoided if not
  strictly necessary.
}
doc {Backup API} {backup.html} {
  The [sqlite3_backup_init | online-backup interface] can be used to
  copy content from a disk file into an in-memory database or vice
  versa and it can make a hot backup of a live database.  This application
  note gives examples of how.
}
doc {Error and Warning Log} {errlog.html} {
  SQLite supports an "error and warning log" design to capture information
  about suspicious and/or error events during operation.  Embedded applications
  are encouraged to enable the error and warning log to help with debugging
  application problems that arise in the field.  This document explains how
  to do that.
}
doc {Foreign Key Support} {foreignkeys.html} {
  This document describes the support for foreign key constraints introduced
  in version 3.6.19.
}
doc {Indexes On Expressions} {expridx.html} {
  Notes on how to create indexes on expressions instead of just
  individual columns.
}
doc {Internal versus External Blob Storage} {intern-v-extern-blob.html} {
  Should you store large BLOBs directly in the database, or store them
  in files and just record the filename in the database?  This document
  seeks to shed light on that question.
}
doc {Limits In SQLite} {limits.html} {
  This document describes limitations of SQLite (the maximum length of a
  string or blob, the maximum size of a database, the maximum number of
  tables in a database, etc.) and how these limits can be altered at
  compile-time and run-time.
}
doc {Memory-Mapped I/O} {mmap.html} {
  SQLite supports memory-mapped I/O.  Learn how to enable memory-mapped
  I/O and about the various advantages and disadvantages to using
  memory-mapped I/O in this document.
}
doc {Multi-threaded Programs and SQLite} {threadsafe.html} {
  SQLite is safe to use in multi-threaded programs.  This document
  provides the details and hints on how to maximize performance.
}
doc {Null Handling} {nulls.html} {
  Different SQL database engines handle NULLs in different ways.  The
  SQL standards are ambiguous.  This (circa 2003) document describes
  how SQLite handles NULLs in comparison with other SQL database engines.
}
doc {Partial Indexes} {partialindex.html} {
  A partial index is an index that only covers a subset of the rows in
  a table.  Learn how to use partial indexes in SQLite from this document.
}
doc {Shared Cache Mode} {sharedcache.html} {
  Version 3.3.0 and later supports the ability for two or more
  database connections to share the same page and schema cache.
  This feature is useful for certain specialized applications.
}
doc {Unlock Notify} {unlock_notify.html} {
  The "unlock notify" feature can be used in conjunction with
  [shared cache mode] to more efficiently manage resource conflict (database
  table locks).
}
doc {URI Filenames} {uri.html} {
  The names of database files can be specified using either an ordinary
  filename or a URI.  Using URI filenames provides additional capabilities,
  as this document describes.
}
doc {WITHOUT ROWID Tables} {withoutrowid.html} {
  The WITHOUT ROWID optimization is a option that can sometimes result
  in smaller and faster databases.
}
doc {Write-Ahead Log (WAL) Mode} {wal.html} {
  Transaction control using a write-ahead log offers more concurrency and
  is often faster than the default rollback transactions.  This document
  explains how to use WAL mode for improved performance.
}

###############################################################################
heading {Tools} tools {
  Information about tools for using and analyzing SQLite
}
doc {Command-Line Shell (sqlite3.exe)} {cli.html} {
  Notes on using the "sqlite3.exe" command-line interface that
  can be used to create, modify, and query arbitrary SQLite
  database files.
}
doc {SQLite Database Analyzer (sqlite3_analyzer.exe)} {sqlanalyze.html} {
  This stand-alone program reads an SQLite database and outputs a file
  showing the space used by each table and index and other statistics.
  Built using the [dbstat virtual table].
}
doc {RBU} {rbu.html} {
  The "Resumable Bulk Update" utility program allows a batch of changes
  to be applied to a remote database running on embedded hardware in a
  way that is resumeable and does not interrupt ongoing operation.
}
doc {SQLite Database Diff (sqldiff.exe)} {sqldiff.html} {
  This stand-alone program compares two SQLite database files and
  outputs the SQL needed to convert one into the other.
}
doc {Database Hash (dbhash.exe)} {dbhash.html} {
  This program demonstrates how to compute a hash over the content
  of an SQLite database.
}
doc {Fossil} {http://www.fossil-scm.org/} {
  The Fossil Version Control System is a distributed VCS designed specifically
  to support SQLite development.  Fossil uses SQLite as for storage.
}
doc {SQLite Archiver (sqlar.exe)} {http://www.sqlite.org/sqlar/} {
  A ZIP-like archive program that uses SQLite for storage.
}

###############################################################################
heading {Advocacy} advocacy {
  Documents that strive to encourage the use of SQLite.
}
doc {SQLite As An Application File Format} {appfileformat.html} {
  This article advocates using SQLite as an application file format
  in place of XML or JSON or a "pile-of-file".
}
doc {Well Known Users} {famous.html} {
  This page lists a small subset of the many thousands of devices
  and application programs that make use of SQLite.
}
doc {35% Faster Than The Filesystem} {fasterthanfs.html} {
  This article points out that reading blobs out of an SQLite database
  is often faster than reading the same blobs from individual files in
  the filesystem.
}


###############################################################################
heading {Technical and Design Documentation} technical {
  These documents are oriented toward describing the internal
  implementation details and operation of SQLite.  
}

doc {How Database Corruption Can Occur} {howtocorrupt.html} {
  SQLite is highly resistant to database corruption.  But application,
  OS, and hardware bugs can still result in corrupt database files.
  This article describes many of the ways that SQLite database files
  can go corrupt.
}

doc {Temporary Files Used By SQLite} {tempfiles.html} {
  SQLite can potentially use many different temporary files when
  processing certain SQL statements.  This document describes the
  many kinds of temporary files that SQLite uses and offers suggestions
  for avoiding them on systems where creating a temporary file is an
  expensive operation.
}

doc {In-Memory Databases} {inmemorydb.html} {
  SQLite normally stores content in a disk file.  However, it can also
  be used as an in-memory database engine.  This document explains how.
}

doc {How SQLite Implements Atomic Commit} {atomiccommit.html} {
  A description of the logic within SQLite that implements
  transactions with atomic commit, even in the face of power
  failures.
}

doc {Dynamic Memory Allocation in SQLite} {malloc.html} {
  SQLite has a sophisticated memory allocation subsystem that can be
  configured and customized to meet memory usage requirements of the
  application and that is robust against out-of-memory conditions and
  leak-free.  This document provides the details.
}

doc {Customizing And Porting SQLite} {custombuild.html} {
  This document explains how to customize the build of SQLite and
  how to port SQLite to new platforms.
}

doc {Locking And Concurrency<br>In SQLite Version 3} {lockingv3.html} {
  A description of how the new locking code in version 3 increases
  concurrency and decreases the problem of writer starvation.
}

doc {Isolation In SQLite} {isolation.html} {
  When we say that SQLite transactions are "serializable" what exactly
  does that mean?  How and when are changes made visible within the
  same database connection and to other database connections?
}

doc {Overview Of The Optimizer} {optoverview.html} {
  A quick overview of the various query optimizations that are
  attempted by the SQLite code generator.
}
doc {The Next-Generation Query Planner} {queryplanner-ng.html} {
  Additional information about the SQLite query planner, and in particular
  the redesign of the query planner that occurred for version 3.8.0.
}

doc {Architecture} {arch.html} {
  An architectural overview of the SQLite library, useful for those who want
  to hack the code.
}
doc {VDBE Opcodes} {opcode.html} {
  This document is an automatically generated description of the various
  opcodes that the VDBE understands.  Programmers can use this document as
  a reference to better understand the output of EXPLAIN listings from
  SQLite.
}
doc {Virtual Filesystem} {vfs.html} {
  The "VFS" object is the interface between the SQLite core and the
  underlying operating system.  Learn more about how the VFS object
  works and how to create new VFS objects from this article.
}
doc {Virtual Tables} {vtab.html} {
  This article describes the virtual table mechanism and API in SQLite and how
  it can be used to add new capabilities to the core SQLite library.
}

doc {SQLite File Format} {fileformat2.html} {
  A description of the format used for SQLite database and journal files, and
  other details required to create software to read and write SQLite 
  databases without using SQLite.
}

doc {Compilation Options} {compile.html} {
  This document describes the compile time options that may be set to 
  modify the default behavior of the library or omit optional features
  in order to reduce binary size.
}

doc {Android Bindings for SQLite} {https://sqlite.org/android/} {
  A description of how to compile your own SQLite for Android
  (bypassing the SQLite that is built into Android) together with
  code and makefiles.
}

doc {Debugging Hints} {debugging.html} {
  A list of tricks and techniques used to trace, examine, and understand
  the operation of the core SQLite library.
}

###############################################################################
heading {Upgrading SQLite, Backwards Compatibility} compat

doc {Moving From SQLite 3.5 to 3.6} {35to36.html} {
  A document describing the differences between SQLite version 3.5.9
  and 3.6.0.
}
doc {Moving From SQLite 3.4 to 3.5} {34to35.html} {
  A document describing the differences between SQLite version 3.4.2
  and 3.5.0.
}
doc {Release History} {changes.html} {
  A chronology of SQLite releases going back to version 1.0.0
}
doc {Backwards Compatibility} {formatchng.html} {
  This document details all of the incompatible changes to the SQLite
  file format that have occurred since version 1.0.0.
}

doc {Private Branches} {privatebranch.html} {
  This document suggests procedures for maintaining a private branch
  or fork of SQLite and keeping that branch or fork in sync with the
  public SQLite source tree.
}


###############################################################################
heading {Obsolete Documents} obsolete {
  The following documents are no longer current and are retained
  for historical reference only.
  These documents generally pertain to out-of-date, obsolete, and/or
  deprecated features and extensions.
}
doc {Asynchronous IO Mode} {asyncvfs.html} {
  This page describes the asynchronous IO extension developed alongside
  SQLite. Using asynchronous IO can cause SQLite to appear more responsive
  by delegating database writes to a background thread.  <i>NB:  This
  extension is deprecated.  [WAL mode] is recommended as a replacement.</i>
}
doc {Version 2 C/C++ API} {c_interface.html} {
  A description of the C/C++ interface bindings for SQLite through version 
  2.8
}
doc {Version 2 DataTypes } {datatypes.html} {
  A description of how SQLite version 2 handles SQL datatypes.
  Short summary:  Everything is a string.
}
doc {VDBE Tutorial} {vdbe.html} {
  The VDBE is the subsystem within SQLite that does the actual work of
  executing SQL statements.  This page describes the principles of operation
  for the VDBE in SQLite version 2.7.  This is essential reading for anyone
  who want to modify the SQLite sources.
}
doc {SQLite Version 3} {version3.html} {
  A summary of the changes between SQLite version 2.8 and SQLite version 3.0.
}
doc {Version 3 C/C++ API} {capi3.html} {
  A summary of the API related changes between SQLite version 2.8 and 
  SQLite version 3.0. 
}
doc {Speed Comparison} {speed.html} {
  The speed of version 2.7.6 of SQLite is compared against PostgreSQL and
  MySQL.
}
