###############################################################################
# The following macros should be defined before this script is
# invoked:
#
# DOC              The toplevel directory of the documentation source tree.
#
# SRC              The toplevel directory of the source code source tree.
#
# BLD              The directory in which the current source code has been
#                  built using "make sqlite3.c"
#
# TH3              The toplevel directory for TH3.  May be an empty string.
#
# SLT              The toplevel directory for SQLLogicTest.  May be an
#                  empty string
#
# TCLFLAGS         Extra C-compiler options needed to link against TCL
#
# TCLSTUBFLAGS     Extra C-compiler options needed to link a TCL extension
#
# NAWK             Nawk compatible awk program.  Older (obsolete?) solaris
#                  systems need this to avoid using the original AT&T AWK.
#
# CC               A C-compiler and arguments for building utility programs
#
# Once the macros above are defined, the rest of this make script will
# build the SQLite library and testing tools.
################################################################################

TCLSH = tclsh.docsrc

default:	
	@echo 'make base;       # Build base documents'
	@echo 'make evidence;   # Gather evidence marks'
	@echo 'make matrix;     # Build the traceability matrix'
	@echo 'make all;        # Do all of the above'
	@echo 'make spell;      # Spell check generated docs'
	@echo 'make searchdb;   # Construct the FTS search database'
	@echo 'make fast;       # Build documentation only - no requirements'
	@echo 'make schema;     # Run once to initialize the build process'

all:	base evidence format_evidence matrix doc

private:	base evidence private_evidence matrix doc

fast:	base doc

sqlite3.h: $(BLD)/sqlite3.h
	cp $(BLD)/sqlite3.h orig-sqlite3.h
	sed 's/^SQLITE_API //' orig-sqlite3.h >sqlite3.h

# Generate the directory into which generated documentation files will
# be written.
#
docdir:
	mkdir -p doc doc/c3ref doc/matrix doc/matrix/c3ref doc/matrix/syntax

# This rule generates all documention files from their sources.  The
# special markup on HTML files used to identify testable statements and
# requirements are retained in the HTML and so the HTML generated by
# this rule is not suitable for publication.  This is the first step
# only.
#
base:	$(TCLSH) sqlite3.h docdir always 
	rm -rf doc/images
	cp -r $(DOC)/images doc
	mkdir doc/images/syntax
	cp $(DOC)/art/syntax/*.gif doc/images/syntax
	cp $(DOC)/rawpages/* doc
	./$(TCLSH) $(DOC)/wrap.tcl $(DOC) $(SRC) doc $(DOC)/pages/*.in
	cp doc/fileformat2.html doc/fileformat.html

# Strip the special markup in HTML files that identifies testable statements
# and requirements.
#
doc:	always $(DOC)/remove_carets.sh
	sh $(DOC)/remove_carets.sh doc

# Spell check generated docs.
#
spell: $(DOC)/spell_chk.sh $(DOC)/custom.txt
	sh $(DOC)/spell_chk.sh doc '*.html' $(DOC)/custom.txt

# Construct the database schema.
#
schema:	$(TCLSH)
	./$(TCLSH) $(DOC)/schema.tcl

# The following rule scans sqlite3.c source text, the text of the TCL
# test cases, and (optionally) the TH3 test case sources looking for
# comments that identify assertions and test cases that provide evidence
# that SQLite behaves as it says it does.  See the comments in 
# scan_test_cases.tcl for additional information.
#
# The output file evidence.txt is used by requirements coverage analysis.
#
SCANNER = $(DOC)/scan_test_cases.tcl

evidence:	$(TCLSH)
	./$(TCLSH) $(SCANNER) -reset src $(SRC)/src/*.[chy]
	./$(TCLSH) $(SCANNER) src $(SRC)/ext/fts3/*.[ch]
	./$(TCLSH) $(SCANNER) src $(SRC)/ext/rtree/*.[ch]
	./$(TCLSH) $(SCANNER) tcl $(SRC)/test/*.test
	if test '' != '$(TH3)'; then \
	  ./$(TCLSH) $(SCANNER) th3 $(TH3)/mkth3.tcl; \
	  ./$(TCLSH) $(SCANNER) th3 $(TH3)/base/*.c; \
	  ./$(TCLSH) $(SCANNER) th3/req1 $(TH3)/req1/*.test; \
	  ./$(TCLSH) $(SCANNER) th3/cov1 $(TH3)/cov1/*.test; \
	  ./$(TCLSH) $(SCANNER) th3/stress $(TH3)/stress/*.test; \
	fi
	if test '' != '$(SLT)'; then \
	  ./$(TCLSH) $(SCANNER) slt $(SLT)/test/evidence/*.test; \
	fi

# Copy and HTMLize evidence files
#
FMT = $(DOC)/format_evidence.tcl

format_evidence: $(TCLSH)
	rm -fr doc/matrix/ev/*
	./$(TCLSH) $(FMT) src doc/matrix $(SRC)/src/*.[chy]
	./$(TCLSH) $(FMT) src doc/matrix $(SRC)/ext/fts3/*.[ch]
	./$(TCLSH) $(FMT) src doc/matrix $(SRC)/ext/rtree/*.[ch]
	./$(TCLSH) $(FMT) tcl doc/matrix $(SRC)/test/*.test
	if test '' != '$(SLT)'; then \
	  ./$(TCLSH) $(FMT) slt doc/matrix $(SLT)/test/evidence/*.test; \
	fi

private_evidence: format_evidence
	./$(TCLSH) $(FMT) th3 doc/matrix $(TH3)/mkth3.tcl
	./$(TCLSH) $(FMT) th3/req1 doc/matrix $(TH3)/req1/*.test
	./$(TCLSH) $(FMT) th3/cov1 doc/matrix $(TH3)/cov1/*.test

# Generate the traceability matrix
#
matrix:	
	rm -rf doc/matrix/images
	cp -r doc/images doc/matrix
	cp $(DOC)/rawpages/sqlite.css doc/matrix
	./$(TCLSH) $(DOC)/matrix.tcl


#-------------------------------------------------------------------------

# Source files for the [tclsqlite3.search] executable. 
#
SSRC = $(DOC)/search/searchc.c \
	    $(DOC)/search/parsehtml.c \
	    $(DOC)/search/fts5ext.c \
	    $(BLD)/tclsqlite3.c

# Flags to build [tclsqlite3.search] with.
#
SFLAGS = $(TCLINC) -DSQLITE_THREADSAFE=0 -DSQLITE_ENABLE_FTS5 -DSQLITE_TCLMD5 -DTCLSH -Dmain=xmain

$(TCLSH): $(SSRC)
	$(CC) -O2 -o $@ -I. $(SFLAGS) $(SSRC) $(TCLFLAGS)

searchdb: $(TCLSH)
	mkdir -p doc/search.d/
	./$(TCLSH) $(DOC)/search/buildsearchdb.tcl
	cp $(DOC)/document_header.tcl doc/document_header.tcl
	cp $(DOC)/document_header.tcl doc/search.d/document_header.tcl
	cp $(DOC)/search/search.tcl doc/search
	chmod +x doc/search
	cp $(DOC)/search/search.tcl doc/search.d/admin
	chmod +x doc/search.d/admin

fts5ext.so:	$(DOC)/search/fts5ext.c
	gcc -shared -fPIC -I. -DSQLITE_EXT \
		$(DOC)/search/fts5ext.c -o fts5ext.so

always:	

clean:	
	rm -rf $(TCLSH) doc sqlite3.h
