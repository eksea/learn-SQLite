
/*
** This file contains the [parsehtml] command, a helper command used to extract
** text and markup tags from the HTML documents in the documentation.
*/

#include <tcl.h>
#include <string.h>
#include <strings.h>
#include <assert.h>
#include <ctype.h>
#include <math.h>

#define ISSPACE(c) (((c)&0x80)==0 && isspace(c))

#include "sqlite3.h"

typedef unsigned int u32;
typedef unsigned char u8;
typedef sqlite3_uint64 u64;


static int doTagCallback(
  Tcl_Interp *interp,
  Tcl_Obj **aCall,
  int nElem,
  const char *zTag, int nTag,
  int iOffset, int iEndOffset,
  Tcl_Obj *pParam
){
  int rc;
  Tcl_Obj *pArg = pParam;
  if( pArg==0 ) pArg = Tcl_NewObj();

  Tcl_IncrRefCount( aCall[nElem]   = Tcl_NewStringObj(zTag, nTag) );
  Tcl_IncrRefCount( aCall[nElem+1] = pArg );
  Tcl_IncrRefCount( aCall[nElem+2] = Tcl_NewIntObj(iOffset) );
  Tcl_IncrRefCount( aCall[nElem+3] = Tcl_NewIntObj(iEndOffset) );

  rc = Tcl_EvalObjv(interp, nElem+4, aCall, 0);

  Tcl_DecrRefCount( aCall[nElem] );
  Tcl_DecrRefCount( aCall[nElem+1] );
  Tcl_DecrRefCount( aCall[nElem+2] );
  Tcl_DecrRefCount( aCall[nElem+3] );
  return rc;
}

static int doTextCallback(
  Tcl_Interp *interp,
  Tcl_Obj **aCall,
  int nElem,
  const char *zText, int nText,
  int iOffset, int iEndOffset
){
  int rc = TCL_OK;
  if( nText>0 ){
    Tcl_Obj *pText = Tcl_NewStringObj(zText, nText);
    rc = doTagCallback(interp, aCall, nElem, "", 0, iOffset, iEndOffset, pText);
  }
  return rc;
}


/*
** Tcl command: parsehtml HTML SCRIPT
*/
static int parsehtmlcmd(
  ClientData clientData,
  Tcl_Interp *interp,
  int objc,
  Tcl_Obj * const objv[]
){
  char *zHtml;
  char *z;
  Tcl_Obj **aCall;
  int nElem;
  Tcl_Obj **aElem;
  int rc;

  if( objc!=3 ){
    Tcl_WrongNumArgs(interp, 1, objv, "HTML SCRIPT");
    return TCL_ERROR;
  }
  zHtml = Tcl_GetString(objv[1]);

  rc = Tcl_ListObjGetElements(interp, objv[2], &nElem, &aElem);
  if( rc!=TCL_OK ) return rc;
  aCall = (Tcl_Obj **)ckalloc(sizeof(Tcl_Obj *)*(nElem+4));
  memcpy(aCall, aElem, sizeof(Tcl_Obj *)*nElem);
  memset(&aCall[nElem], 0, 3*sizeof(Tcl_Obj*));

  z = zHtml;
  while( *z ){
    char *zText = z;
    while( *z && *z!='<' ) z++;

    /* Invoke the callback script for the chunk of text just parsed. */
    rc = doTextCallback(interp,aCall,nElem,zText,z-zText,zText-zHtml,z-zHtml);
    if( rc!=TCL_OK ) return rc;

    /* Unless is at the end of the document, z now points to the start of a
    ** markup tag. Either an opening or a closing tag. Parse it up and 
    ** invoke the callback script. */
    if( *z ){
      int nTag;
      char *zTag;
      int iOffset;                /* Offset of open tag (the '<' character) */

      assert( *z=='<' );
      iOffset = z - zHtml;
      z++;

      while( ISSPACE(*z) ) z++;
      zTag = z;

      while( *z && !ISSPACE(*z) && *z!='>' ) z++;
      nTag = z-zTag;

      if( nTag==5 && 0==strncasecmp("style", zTag, 5) ){
        while( *z && strncasecmp("/style>", z, 7 ) ) z++;
      } else if( nTag>=3 && 0==memcmp("!--", zTag, 3) ){
        while( *z && strncasecmp("-->", z, 3 ) ) z++;
      } else if( nTag>=3 && 0==memcmp("script", zTag, 6) ){
        while( *z && strncasecmp("/script>", z, 8 ) ) z++;
      } else {
        Tcl_Obj *pParam = Tcl_NewObj();

        while( *z && *z!='>' ){
          char *zAttr;

          /* Gobble up white-space */
          while( ISSPACE(*z) ) z++;
          zAttr = z;

          /* Advance to the end of the attribute name */
          while( *z && *z!='>' && !ISSPACE(*z) && *z!='=' ) z++;
          if( z==zAttr ) zAttr = 0;

          if( zAttr ){
            Tcl_Obj *pAttr = Tcl_NewStringObj(zAttr, z-zAttr);
            Tcl_ListObjAppendElement(interp, pParam, pAttr);
          }
          while( ISSPACE(*z) ) z++;

          if( *z=='=' ){
            int nVal;
            char *zVal;
            z++;
            while( ISSPACE(*z) ) z++;
            zVal = z;

            if( *zVal=='"' ){
              zVal++;
              z++;
              while( *z && *z!='"' ) z++;
              nVal = z-zVal;
              z++;
            }else{
              while( *z && !ISSPACE(*z) && *z!='>' ) z++;
              nVal = z-zVal;
            }
            Tcl_ListObjAppendElement(interp,pParam,Tcl_NewStringObj(zVal,nVal));
          }else if( zAttr ){
            Tcl_ListObjAppendElement(interp, pParam, Tcl_NewIntObj(1));
          }
        }
        
        rc = doTagCallback(interp, 
            aCall, nElem, zTag, nTag, iOffset, 1+z-zHtml, pParam
        );
        if( rc!=TCL_OK ) return rc;

        if( nTag==3 && memcmp(zTag, "tcl", 3)==0 ){
          const char *zText = &z[1];
          while( *z && strncasecmp("</tcl>", z, 6) ) z++;
          rc = doTextCallback(interp, aCall, nElem, zText, z-zText, 0, 0);
          if( rc!=TCL_OK ) return rc;
          rc = doTagCallback(interp, aCall, nElem, "/tcl", 4, 0, 0, 0);
          if( rc!=TCL_OK ) return rc;
          if( *z ) z++;
        }
      }

      while( *z && !ISSPACE(*z) && *z!='>' ) z++;
      if( *z ) z++;
    }

  }

  return TCL_OK;
}

int Parsehtml_Init(Tcl_Interp *interp){

#ifdef USE_TCL_STUBS
  if (Tcl_InitStubs(interp, "8.4", 0) == 0) {
    return TCL_ERROR;
  }
#endif

  Tcl_CreateObjCommand(interp, "parsehtml",  parsehtmlcmd, 0, 0);

  return TCL_OK;
}

