
/*
** This file contains the implementation of a custom FTS5 tokenizer. This
** tokenizer implements the following special features:
**
**   * For all tokens that match the pattern "SQLITE_XXX" (case sensitive),
**     "XXX" is added as a synonym for SQLITE_XXX.
**
**   * For all tokens that match the pattern "sqlite3_xxx" (case sensitive),
**     "xxx" is added as a synonym for sqlite3_xxx.
**
** By default, this file builds a TCL extension.  But if the -DSQLITE_EXT
** compile-time option is used, then an SQLite extension is built instead.
*/

#ifdef SQLITE_EXT
#include "sqlite3ext.h"
SQLITE_EXTENSION_INIT1
#else
#include <sqlite3.h>
#include <tcl.h>
#endif
#include <string.h>
#include <assert.h>


/*************************************************************************
** This is generic code copied from the FTS5 documentation.
**
** Return a pointer to the fts5_api pointer for database connection db.
** If an error occurs, return NULL and leave an error in the database 
** handle (accessible using sqlite3_errcode()/errmsg()).
*/
fts5_api *fts5_api_from_db(sqlite3 *db){
  fts5_api *pRet = 0;
  sqlite3_stmt *pStmt = 0;
  if( SQLITE_OK==sqlite3_prepare(db, "SELECT fts5(?1)", -1, &pStmt, 0) ){
    sqlite3_bind_pointer(pStmt, 1, (void*)&pRet, "fts5_api_ptr", 0);
    sqlite3_step(pStmt);
  }
  sqlite3_finalize(pStmt);
  return pRet;
}
/************************************************************************/

/*
** Simple ranking function used by search script. Assumes the queried
** table has the following 5 indexed columns:
**
**     apis,                      -- C APIs 
**     keywords,                  -- Keywords
**     title1,                    -- Document title
**     title2,                    -- Heading title, if any
**     content,                   -- Document text
**
** This function returns the following integer values:
**
**   10000 - all phrases present in "keywords".
**   1000 - all phrases present in "keywords", "title1" or "title2".
**   100 - all phrases present in "keywords", "title1" or "title2" or "apis".
**
** It adds a bonus of 10 if either of the above and the condition 
** (xRowid()>1000 && (xRowid() % 1000)==1) is true.
**
*/
void srankFunc(
  const Fts5ExtensionApi *pApi,   /* API offered by current FTS version */
  Fts5Context *pFts,              /* First arg to pass to pApi functions */
  sqlite3_context *pCtx,          /* Context for returning result/error */
  int nVal,                       /* Number of values in apVal[] array */
  sqlite3_value **apVal           /* Array of trailing arguments */
){
  int nPhrase;                    /* Number of phrases in query */
  int i;                          /* Used to iterate through phrases */
  int rc;                         /* Return code */
  int n1 = 0;
  int n2 = 0;
  int n3 = 0;
  int iScore = 0;                 /* Returned value */
  sqlite3_int64 iRowid;           /* Rowid for current row */

  iRowid = pApi->xRowid(pFts);
#if 0
  if( iRowid<1000 ) return;
#endif
  nPhrase = pApi->xPhraseCount(pFts);
  for(i=0; i<nPhrase; i++){
    Fts5PhraseIter iter;
    int ic, io;

    rc = pApi->xPhraseFirst(pFts, i, &iter, &ic, &io);
    if( rc!=SQLITE_OK ){
      sqlite3_result_error(pCtx, "Error in xPhraseFirst/xPhraseNext", -1);
      return;
    }

    if( ic==0 ){
      while( ic==0 ) pApi->xPhraseNext(pFts, &iter, &ic, &io);
      if( ic<0 ) ic = 0;
    }

    if( ic==1 ) n1++;
    if( ic==2 || ic==3 ) n2++;
    if( ic==0 ) n3++;
  }

  if( n1==nPhrase ){ iScore = 10000; }
  else if( n1+n2==nPhrase ){ iScore = 1000; }
  else if( n1+n2+n3==nPhrase ){ iScore = 100; }

  if( iScore && iRowid>1000 && (iRowid % 1000)==1 ){
    iScore += 10;
  }

  sqlite3_result_int(pCtx, iScore);
}



typedef struct STokenizer STokenizer;
typedef struct STokenCtx STokenCtx;

/*
** Tokenizer type. Casts to Fts5Tokenizer.
*/
struct STokenizer {
  fts5_tokenizer porter;
  Fts5Tokenizer *pPorter;
};

/*
** Context passed through underlying tokenizer to wrapper callback.
*/
struct STokenCtx {
  void *pCtx;
  int (*xToken)(void*, int, const char*, int, int, int);
};

static int stokenCreate(
  void *pCtx, 
  const char **azArg, int nArg, 
  Fts5Tokenizer **ppOut
){
  fts5_api *pApi = (fts5_api*)pCtx;
  STokenizer *p;
  void *pPorterCtx;
  int rc;

  /* Allocate the Fts5Tokenizer object for this tokenizer. */
  p = sqlite3_malloc(sizeof(STokenizer));
  if( p ){
    memset(p, 0, sizeof(STokenizer));
  }else{
    return SQLITE_NOMEM;
  }

  /* Locate and allocate the porter tokenizer */
  rc = pApi->xFindTokenizer(pApi, "porter", &pPorterCtx, &p->porter);
  if( rc==SQLITE_OK ){
    rc = p->porter.xCreate(pPorterCtx, azArg, nArg, &p->pPorter);
  }

  /* Return the new tokenizer to the caller */
  if( rc!=SQLITE_OK ){
    sqlite3_free(p);
    p = 0;
  }
  *ppOut = (Fts5Tokenizer*)p;
  return rc;
}

static void stokenDelete(Fts5Tokenizer *pTokenizer){
  STokenizer *p = (STokenizer*)pTokenizer;
  p->porter.xDelete(p->pPorter);
  sqlite3_free(p);
}

static int stokenTokenizeCb(
  void *pCtx,         /* Copy of 2nd argument to xTokenize() */
  int tflags,         /* Mask of FTS5_TOKEN_* flags */
  const char *pToken, /* Pointer to buffer containing token */
  int nToken,         /* Size of token in bytes */
  int iStart,         /* Byte offset of token within input text */
  int iEnd            /* Byte offset of end of token within input text */
){
  STokenCtx *p = (STokenCtx*)pCtx;
  int rc = p->xToken(p->pCtx, 0, pToken, nToken, iStart, iEnd);
  if( rc==SQLITE_OK && nToken>7 && 0==memcmp("sqlite_", pToken, 7) ){
    rc = p->xToken(
        p->pCtx, FTS5_TOKEN_COLOCATED, pToken+7, nToken-7, iStart, iEnd);
  }

  if( rc==SQLITE_OK && nToken>8 && 0==memcmp("sqlite3_", pToken, 8) ){
    rc = p->xToken(
        p->pCtx, FTS5_TOKEN_COLOCATED, pToken+8, nToken-8, iStart, iEnd);
  }

  return rc;
}

/*
** Tokenizer type for "html" tokenizer. Casts to Fts5Tokenizer.
*/
typedef struct HtmlTokenizer HtmlTokenizer;
struct HtmlTokenizer {
  fts5_tokenizer tokenizer;
  Fts5Tokenizer *pTokenizer;
};

static int htmlCreate(
  void *pCtx, 
  const char **azArg, int nArg, 
  Fts5Tokenizer **ppOut
){
  fts5_api *pApi = (fts5_api*)pCtx;
  HtmlTokenizer *p = 0;
  int rc = SQLITE_OK;

  if( nArg==0 ){
    rc = SQLITE_ERROR;
  }else{
    /* Allocate the Fts5Tokenizer object for this tokenizer. */
    p = sqlite3_malloc(sizeof(HtmlTokenizer));
    if( p ){
      memset(p, 0, sizeof(HtmlTokenizer));
    }else{
      return SQLITE_NOMEM;
    }
  }

  if( rc==SQLITE_OK ){
    /* Locate and allocate the next tokenizer */
    void *pNextCtx = 0;
    rc = pApi->xFindTokenizer(pApi, azArg[0], &pNextCtx, &p->tokenizer);
    if( rc==SQLITE_OK ){
      rc = p->tokenizer.xCreate(pNextCtx, &azArg[1], nArg-1, &p->pTokenizer);
    }
  }

  /* Return the new tokenizer to the caller */
  if( rc!=SQLITE_OK ){
    sqlite3_free(p);
    p = 0;
  }
  *ppOut = (Fts5Tokenizer*)p;
  return rc;
}

static void htmlDelete(Fts5Tokenizer *pTokenizer){
  HtmlTokenizer *p = (HtmlTokenizer*)pTokenizer;
  p->tokenizer.xDelete(p->pTokenizer);
  sqlite3_free(p);
}

static int htmlTokenize(
  Fts5Tokenizer *pTokenizer, 
  void *pCtx,
  int flags,            /* Mask of FTS5_TOKENIZE_* flags */
  const char *pText, int nText, 
  int (*xToken)(
    void *pCtx,         /* Copy of 2nd argument to xTokenize() */
    int tflags,         /* Mask of FTS5_TOKEN_* flags */
    const char *pToken, /* Pointer to buffer containing token */
    int nToken,         /* Size of token in bytes */
    int iStart,         /* Byte offset of token within input text */
    int iEnd            /* Byte offset of end of token within input text */
  )
){
  HtmlTokenizer *p = (HtmlTokenizer*)pTokenizer;
  char *zOut;
  int i;
  int bTag=0;
  int rc;
  
  zOut = sqlite3_malloc(nText+1);
  if( zOut==0 ){
    return SQLITE_NOMEM;
  }
  for(i=0; i<nText; i++){
    char c = pText[i];
    if( bTag==0 && c=='<' ) bTag = 1;
    zOut[i] = bTag ? ' ' : c;
    if( bTag==1 && c=='>' ) bTag = 0;
  }

  rc = p->tokenizer.xTokenize(p->pTokenizer, pCtx, flags, zOut, nText, xToken);
  sqlite3_free(zOut);
  return rc;
}

static int stokenTokenize(
  Fts5Tokenizer *pTokenizer, 
  void *pCtx,
  int flags,            /* Mask of FTS5_TOKENIZE_* flags */
  const char *pText, int nText, 
  int (*xToken)(
    void *pCtx,         /* Copy of 2nd argument to xTokenize() */
    int tflags,         /* Mask of FTS5_TOKEN_* flags */
    const char *pToken, /* Pointer to buffer containing token */
    int nToken,         /* Size of token in bytes */
    int iStart,         /* Byte offset of token within input text */
    int iEnd            /* Byte offset of end of token within input text */
  )
){
  STokenizer *p = (STokenizer*)pTokenizer;
  int rc;

  if( flags==FTS5_TOKENIZE_DOCUMENT ){
    STokenCtx ctx;
    ctx.xToken = xToken;
    ctx.pCtx = pCtx;
    rc = p->porter.xTokenize(
        p->pPorter, (void*)&ctx, flags, pText, nText, stokenTokenizeCb
    );
  }else{
    rc = p->porter.xTokenize(p->pPorter, pCtx, flags, pText, nText, xToken);
  }

  return rc;
}


static int register_tokenizer(sqlite3 *db, char **pzErr, void *p){
  fts5_api *pApi;
  fts5_tokenizer t;
  int rc;

  pApi = fts5_api_from_db(db);
  if( pApi==0 ){
    *pzErr = sqlite3_mprintf("fts5_api_from_db: %s", sqlite3_errmsg(db));
    return SQLITE_ERROR;
  }

  t.xCreate = stokenCreate;
  t.xDelete = stokenDelete;
  t.xTokenize = stokenTokenize;
  rc = pApi->xCreateTokenizer(pApi, "stoken", (void*)pApi, &t, 0);

  if( rc==SQLITE_OK ){
    t.xCreate = htmlCreate;
    t.xDelete = htmlDelete;
    t.xTokenize = htmlTokenize;
    rc = pApi->xCreateTokenizer(pApi, "html", (void*)pApi, &t, 0);
  }

  if( rc==SQLITE_OK ){
    rc = pApi->xCreateFunction(pApi, "srank", 0, srankFunc, 0);
  }

  return rc;
}

#ifdef SQLITE_EXT
#ifdef _WIN32
__declspec(dllexport)
#endif
int sqlite3_ftsext_init(
  sqlite3 *db, 
  char **pzErrMsg, 
  const sqlite3_api_routines *pApi
){
  int rc = SQLITE_OK;
  SQLITE_EXTENSION_INIT2(pApi);
  (void)pzErrMsg;  /* Unused parameter */
  rc = register_tokenizer(db, 0, 0);
  return rc;
}

#else
int Fts5ext_Init(Tcl_Interp *interp){
#ifdef USE_TCL_STUBS
  if (Tcl_InitStubs(interp, "8.4", 0) == 0) {
    return TCL_ERROR;
  }
#endif
  sqlite3_auto_extension((void (*)(void))register_tokenizer);
  return TCL_OK;
}
#endif
