

#include <sqlite3.h>
#include <tcl.h>

int Sqlite3_Init(Tcl_Interp*);
int Parsehtml_Init(Tcl_Interp*);
int Fts5ext_Init(Tcl_Interp*);

#ifdef SQLITE_TCLMD5
int Md5_Init(Tcl_Interp*);
#endif

static int AppInit(Tcl_Interp *interp) {
  int rc;
  rc = Sqlite3_Init(interp);
  if( rc!=TCL_OK ) return rc;

  rc = Parsehtml_Init(interp);
  if( rc!=TCL_OK ) return rc;

  rc = Fts5ext_Init(interp);
  if( rc!=TCL_OK ) return rc;

#ifdef SQLITE_TCLMD5
  rc = Md5_Init(interp);
  if( rc!=TCL_OK ) return rc;
#endif

  return TCL_OK;
}

#ifdef main
# undef main
#endif

int main(int argc, char *argv[]) {
  Tcl_Main(argc, argv, AppInit);
  return 0;
}

