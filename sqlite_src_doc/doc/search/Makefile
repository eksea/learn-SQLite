#CFLAGS = -g -DSQLITE_MEMDEBUG -DSQLITE_DEBUG
#CFLAGS = -g -O2 -DNDEBUG
CFLAGS = -Os -DNDEBUG

TCLSQLITE3C = /home/dan/work/sqliteG/bld/tclsqlite3.c

LIBSQLITE3A = /home/dan/work/sqliteG/bld/libsqlite3.a
TCLSQLITEC = /home/dan/work/sqliteG/sqlite/src/tclsqlite.c

#SQLITELIB = $(TCLSQLITEC) $(LIBSQLITE3A)
SQLITELIB = $(TCLSQLITE3C)

tclsqlite3.fts3: searchc.c $(SQLITELIB)
	gcc $(CFLAGS) -DSQLITE_ENABLE_FTS3 searchc.c $(SQLITELIB) -I/home/dan/work/sqliteG/sqlite/ext/fts3/ -static -L/home/dan/tcl86/lib -ltcl8.6 -ldl -lm -o tclsqlite3.fts3 -lz -lpthread

clean:
	rm tclsqlite3.fts3

	#gcc $(CFLAGS) -DSQLITE_ENABLE_FTS3 -I/home/dan/work/sqliteG/sqlite/ext/fts3/ -static searchc.c /home/dan/work/sqliteG/bld/tclsqlite3.c -L/home/dan/tcl86/lib -ltcl8.6 -ldl -lm -o tclsqlite3.fts3 -lz -lpthread
