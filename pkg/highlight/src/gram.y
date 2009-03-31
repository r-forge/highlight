%{
/*{{{ Prologue */
/* :tabSize=4:indentSize=4:noTabs=false:folding=explicit:collapseFolds=1: */

#include "highlight.h"

/* This is used as the buffer for NumericValue, SpecialValue and
   SymbolValue.  None of these could conceivably need 8192 bytes.

   It has not been used as the buffer for input character strings
   since Oct 2007 (released as 2.7.0), and for comments since 2.8.0
 */
static char yytext[MAXELTSIZE];

#define YYERROR_VERBOSE 0

static void yyerror(char *);
static int yylex();
int yyparse(void);

#define yyconst const

typedef struct yyltype{
  int first_line;
  int first_column;
  int first_byte;

  int last_line;
  int last_column;
  int last_byte;
} yyltype;

# define YYLTYPE yyltype
# define YYLLOC_DEFAULT(Current, Rhs, N)				\
    do									\
      if (YYID (N))							\
	{								\
	  (Current).first_line   = YYRHSLOC (Rhs, 1).first_line;	\
	  (Current).first_column = YYRHSLOC (Rhs, 1).first_column;	\
	  (Current).first_byte   = YYRHSLOC (Rhs, 1).first_byte;	\
	  (Current).last_line    = YYRHSLOC (Rhs, N).last_line;		\
	  (Current).last_column  = YYRHSLOC (Rhs, N).last_column;	\
	  (Current).last_byte    = YYRHSLOC (Rhs, N).last_byte;		\
	}								\
      else								\
	{								\
	  (Current).first_line   = (Current).last_line   =		\
	    YYRHSLOC (Rhs, 0).last_line;				\
	  (Current).first_column = (Current).last_column =		\
	    YYRHSLOC (Rhs, 0).last_column;				\
	  (Current).first_byte   = (Current).last_byte =		\
	    YYRHSLOC (Rhs, 0).last_byte;				\
	}								\
    while (YYID (0))

#define LBRACE	'{'
#define RBRACE	'}'

/* Functions used in the parsing process */

static void	CheckFormalArgs(SEXP, SEXP, YYLTYPE* );
static SEXP	TagArg(SEXP, SEXP, YYLTYPE* );
static void IfPush(void);
static void ifpop(void); 
static SEXP	NextArg(SEXP, SEXP, SEXP);
static SEXP	FirstArg(SEXP, SEXP);
static int KeywordLookup(const char*);

/* strecthy list */
static SEXP	NewList(void);
static SEXP	GrowList(SEXP, SEXP);
static SEXP	Insert(SEXP, SEXP);

static SEXP mkComplex(const char *);
static SEXP mkFloat(const char *);
SEXP mkInt(const char *); 
static SEXP mkNA(void);
SEXP mkTrue(void);
SEXP mkFalse(void);

static int	xxgetc();
static int	xxungetc(int);

/* The idea here is that if a string contains \u escapes that are not
   valid in the current locale, we should switch to UTF-8 for that
   string.  Needs wide-char support.
*/


#if defined(SUPPORT_MBCS)
# include <R_ext/rlocale.h>
#ifdef HAVE_LANGINFO_CODESET
# include <langinfo.h>
#endif
/**
 * Gets the next character (one MBCS worth character)
 * 
 * @param c 
 * @param wc
 * @return 
 */ 
static int mbcs_get_next(int c, wchar_t *wc){
	
    int i, res, clen = 1; char s[9];
    mbstate_t mb_st;

    s[0] = c;
    /* This assumes (probably OK) that all MBCS embed ASCII as single-byte
       lead bytes, including control chars */
    if((unsigned int) c < 0x80) {
		*wc = (wchar_t) c;
		return 1;
    }
    if(utf8locale) {
		clen = utf8clen(c);
		for(i = 1; i < clen; i++) {
		    s[i] = xxgetc();  
		    if(s[i] == R_EOF) {
				error(_("EOF whilst reading MBCS char at line %d"), xxlineno);
			}
		}
		res = mbrtowc(wc, s, clen, NULL);
		if(res == -1) {
			error(_("invalid multibyte character in parser at line %d"), xxlineno);
		}
    } else {
		/* This is not necessarily correct for stateful MBCS */
		while(clen <= MB_CUR_MAX) {
		    mbs_init(&mb_st);
		    res = mbrtowc(wc, s, clen, &mb_st);
		    if(res >= 0) break;
		    if(res == -1){
				error(_("invalid multibyte character in parser at line %d"), xxlineno);
			}
		    /* so res == -2 */
		    c = xxgetc();
		    if(c == R_EOF){
				error(_("EOF whilst reading MBCS char at line %d"), xxlineno);
			}
		    s[clen++] = c;
		} /* we've tried enough, so must be complete or invalid by now */
    }
    for(i = clen - 1; i > 0; i--){
		xxungetc(s[i]);
	}
    return clen;
}
#endif 

/* Handle function source */

/*{{{ Routines used to build the parse tree */
static SEXP	xxnullformal(void);
static SEXP	xxfirstformal0(SEXP);
static SEXP	xxfirstformal1(SEXP, SEXP);
static SEXP	xxaddformal0(SEXP, SEXP, YYLTYPE *);
static SEXP	xxaddformal1(SEXP, SEXP, SEXP, YYLTYPE *);
static SEXP	xxexprlist0();
static SEXP	xxexprlist1(SEXP, YYLTYPE *);
static SEXP	xxexprlist2(SEXP, SEXP, YYLTYPE *);
static SEXP	xxsub0(void);
static SEXP	xxsub1(SEXP, YYLTYPE *);
static SEXP	xxsymsub0(SEXP, YYLTYPE *);
static SEXP	xxsymsub1(SEXP, SEXP, YYLTYPE *);
static SEXP	xxnullsub0(YYLTYPE *);
static SEXP	xxnullsub1(SEXP, YYLTYPE *);
static SEXP	xxsublist1(SEXP);
static SEXP	xxsublist2(SEXP, SEXP);
static SEXP	xxcond(SEXP);
static SEXP	xxifcond(SEXP);
static SEXP	xxif(SEXP, SEXP, SEXP);
static SEXP	xxifelse(SEXP, SEXP, SEXP, SEXP);
static SEXP	xxforcond(SEXP, SEXP);
static SEXP	xxfor(SEXP, SEXP, SEXP);
static SEXP	xxwhile(SEXP, SEXP, SEXP);
static SEXP	xxrepeat(SEXP, SEXP);
static SEXP	xxnxtbrk(SEXP);
static SEXP	xxfuncall(SEXP, SEXP);
static SEXP	xxdefun(SEXP, SEXP, SEXP);
static SEXP	xxunary(SEXP, SEXP);
static SEXP	xxbinary(SEXP, SEXP, SEXP);
static SEXP	xxparen(SEXP, SEXP);
static SEXP	xxsubscript(SEXP, SEXP, SEXP);
static SEXP	xxexprlist(SEXP, YYLTYPE *, SEXP);
static int	xxvalue(SEXP, int, YYLTYPE *);
/*}}}*/ 

#define YYSTYPE		SEXP
/*}}} Prologue */
%}
/*{{{ Grammar */
/*{{{ Tokens */
%token		END_OF_INPUT ERROR
%token		STR_CONST NUM_CONST NULL_CONST SYMBOL FUNCTION 
%token		LEFT_ASSIGN EQ_ASSIGN RIGHT_ASSIGN LBB
%token		FOR IN IF ELSE WHILE NEXT BREAK REPEAT
%token		GT GE LT LE EQ NE AND OR AND2 OR2
%token		NS_GET NS_GET_INT
%token		COMMENT
/*}}}*/

/*{{{ This is the precedence table, low to high */
%left		'?'
%left		LOW WHILE FOR REPEAT
%right		IF
%left		ELSE
%right		LEFT_ASSIGN
%right		EQ_ASSIGN
%left		RIGHT_ASSIGN
%left		'~' TILDE
%left		OR OR2
%left		AND AND2
%left		UNOT NOT
%nonassoc   	GT GE LT LE EQ NE
%left		'+' '-'
%left		'*' '/'
%left		SPECIAL
%left		':'
%left		UMINUS UPLUS
%right		'^'
%left		'$' '@'
%left		NS_GET NS_GET_INT
%nonassoc	'(' '[' LBB
/*}}}*/

/*{{{ rules */
%%

prog	:	END_OF_INPUT			{ return 0; }
	|	'\n'				{ return xxvalue(NULL,2,NULL); }
	|	expr_or_assign '\n'			{ return xxvalue($1,3,&@1); }
	|	expr_or_assign ';'			{ return xxvalue($1,4,&@1); }
	|	error	 			{ YYABORT; }
	;

expr_or_assign  :    expr                       { $$ = $1; }
                |    equal_assign               { $$ = $1; }
                ;

equal_assign    :    expr EQ_ASSIGN expr_or_assign              { $$ = xxbinary($2,$1,$3); }
                ;

expr	: 	NUM_CONST			{ $$ = $1; }
	|	STR_CONST			{ $$ = $1; }
	|	NULL_CONST			{ $$ = $1; }
	|	SYMBOL				{ $$ = $1; }

	|	'{' exprlist '}'		{ $$ = xxexprlist($1,&@1,$2); }
	|	'(' expr_or_assign ')'			{ $$ = xxparen($1,$2); }

	|	'-' expr %prec UMINUS		{ $$ = xxunary($1,$2); }
	|	'+' expr %prec UMINUS		{ $$ = xxunary($1,$2); }
	|	'!' expr %prec UNOT		{ $$ = xxunary($1,$2); }
	|	'~' expr %prec TILDE		{ $$ = xxunary($1,$2); }
	|	'?' expr			{ $$ = xxunary($1,$2); }

	|	expr ':'  expr			{ $$ = xxbinary($2,$1,$3); }
	|	expr '+'  expr			{ $$ = xxbinary($2,$1,$3); }
	|	expr '-' expr			{ $$ = xxbinary($2,$1,$3); }
	|	expr '*' expr			{ $$ = xxbinary($2,$1,$3); }
	|	expr '/' expr			{ $$ = xxbinary($2,$1,$3); }
	|	expr '^' expr 			{ $$ = xxbinary($2,$1,$3); }
	|	expr SPECIAL expr		{ $$ = xxbinary($2,$1,$3); }
	|	expr '%' expr			{ $$ = xxbinary($2,$1,$3); }
	|	expr '~' expr			{ $$ = xxbinary($2,$1,$3); }
	|	expr '?' expr			{ $$ = xxbinary($2,$1,$3); }
	|	expr LT expr			{ $$ = xxbinary($2,$1,$3); }
	|	expr LE expr			{ $$ = xxbinary($2,$1,$3); }
	|	expr EQ expr			{ $$ = xxbinary($2,$1,$3); }
	|	expr NE expr			{ $$ = xxbinary($2,$1,$3); }
	|	expr GE expr			{ $$ = xxbinary($2,$1,$3); }
	|	expr GT expr			{ $$ = xxbinary($2,$1,$3); }
	|	expr AND expr			{ $$ = xxbinary($2,$1,$3); }
	|	expr OR expr			{ $$ = xxbinary($2,$1,$3); }
	|	expr AND2 expr			{ $$ = xxbinary($2,$1,$3); }
	|	expr OR2 expr			{ $$ = xxbinary($2,$1,$3); }

	|	expr LEFT_ASSIGN expr 		{ $$ = xxbinary($2,$1,$3); }
	|	expr RIGHT_ASSIGN expr 		{ $$ = xxbinary($2,$3,$1); }
	|	FUNCTION '(' formlist ')' cr expr_or_assign %prec LOW
						{ $$ = xxdefun($1,$3,$6); }
	|	expr '(' sublist ')'		{ $$ = xxfuncall($1,$3); }
	|	IF ifcond expr_or_assign 			{ $$ = xxif($1,$2,$3); }
	|	IF ifcond expr_or_assign ELSE expr_or_assign	{ $$ = xxifelse($1,$2,$3,$5); }
	|	FOR forcond expr_or_assign %prec FOR 	{ $$ = xxfor($1,$2,$3); }
	|	WHILE cond expr_or_assign			{ $$ = xxwhile($1,$2,$3); }
	|	REPEAT expr_or_assign			{ $$ = xxrepeat($1,$2); }
	|	expr LBB sublist ']' ']'	{ $$ = xxsubscript($1,$2,$3); }
	|	expr '[' sublist ']'		{ $$ = xxsubscript($1,$2,$3); }
	|	SYMBOL NS_GET SYMBOL		{ $$ = xxbinary($2,$1,$3); }
	|	SYMBOL NS_GET STR_CONST		{ $$ = xxbinary($2,$1,$3); }
	|	STR_CONST NS_GET SYMBOL		{ $$ = xxbinary($2,$1,$3); }
	|	STR_CONST NS_GET STR_CONST	{ $$ = xxbinary($2,$1,$3); }
	|	SYMBOL NS_GET_INT SYMBOL	{ $$ = xxbinary($2,$1,$3); }
	|	SYMBOL NS_GET_INT STR_CONST	{ $$ = xxbinary($2,$1,$3); }
	|	STR_CONST NS_GET_INT SYMBOL	{ $$ = xxbinary($2,$1,$3); }
	|	STR_CONST NS_GET_INT STR_CONST	{ $$ = xxbinary($2,$1,$3); }
	|	expr '$' SYMBOL			{ $$ = xxbinary($2,$1,$3); }
	|	expr '$' STR_CONST		{ $$ = xxbinary($2,$1,$3); }
	|	expr '@' SYMBOL			{ $$ = xxbinary($2,$1,$3); }
	|	expr '@' STR_CONST		{ $$ = xxbinary($2,$1,$3); }
	|	NEXT				{ $$ = xxnxtbrk($1); }
	|	BREAK				{ $$ = xxnxtbrk($1); }
	;


cond	:	'(' expr ')'			{ $$ = xxcond($2); }
	;

ifcond	:	'(' expr ')'			{ $$ = xxifcond($2); }
	;

forcond :	'(' SYMBOL IN expr ')' 		{ $$ = xxforcond($2,$4); }
	;


exprlist:					{ $$ = xxexprlist0(); }
	|	expr_or_assign			{ $$ = xxexprlist1($1, &@1); }
	|	exprlist ';' expr_or_assign	{ $$ = xxexprlist2($1, $3, &@3); }
	|	exprlist ';'			{ $$ = $1; }
	|	exprlist '\n' expr_or_assign	{ $$ = xxexprlist2($1, $3, &@3); }
	|	exprlist '\n'			{ $$ = $1;}
	;

sublist	:	sub				{ $$ = xxsublist1($1); }
	|	sublist cr ',' sub		{ $$ = xxsublist2($1,$4); }
	;

sub	:					{ $$ = xxsub0(); }
	|	expr				{ $$ = xxsub1($1, &@1); }
	|	SYMBOL EQ_ASSIGN 			{ $$ = xxsymsub0($1, &@1); }
	|	SYMBOL EQ_ASSIGN expr			{ $$ = xxsymsub1($1,$3, &@1); }
	|	STR_CONST EQ_ASSIGN 			{ $$ = xxsymsub0($1, &@1); }
	|	STR_CONST EQ_ASSIGN expr		{ $$ = xxsymsub1($1,$3, &@1); }
	|	NULL_CONST EQ_ASSIGN 			{ $$ = xxnullsub0(&@1); }
	|	NULL_CONST EQ_ASSIGN expr		{ $$ = xxnullsub1($3, &@1); }
	;

formlist:					{ $$ = xxnullformal(); }
	|	SYMBOL				{ $$ = xxfirstformal0($1); }
	|	SYMBOL EQ_ASSIGN expr			{ $$ = xxfirstformal1($1,$3); }
	|	formlist ',' SYMBOL		{ $$ = xxaddformal0($1,$3, &@3); }
	|	formlist ',' SYMBOL EQ_ASSIGN expr	{ $$ = xxaddformal1($1,$3,$5,&@3); }
	;

cr	:					{ EatLines = 1; }
	;
%%
/*}}}*/
/*}}}*/

/* Private pushback, since file ungetc only guarantees one byte.
   We need up to one MBCS-worth */

#define DECLARE_YYTEXT_BUFP(bp) char *bp = yytext
#define YYTEXT_PUSH(c, bp) do { \
    if ((bp) - yytext >= sizeof(yytext) - 1) \
	error(_("input buffer overflow at line %d"), xxlineno); \
	*(bp)++ = (c); \
} while(0)



/*{{{ set of functions used in the parsing process */

/*{{{ Get the next or the previous character from the stream */

/** 
 * Gets the next character
 * 
 * @return the next character
 */
static int xxgetc(void) {
    int c;

    if(npush) {
		c = pushback[--npush]; 
	} else  {
		c = ptr_getc();
	}

    prevpos = (prevpos + 1) % PUSHBACK_BUFSIZE;
    prevcols[prevpos] = xxcolno;
    prevbytes[prevpos] = xxbyteno;
    prevlines[prevpos] = xxlineno;    
    
    if (c == EOF) {
		EndOfFile = 1;
		return R_EOF;
    }
    R_ParseContextLast = (R_ParseContextLast + 1) % PARSE_CONTEXT_SIZE;
    R_ParseContext[R_ParseContextLast] = c;

    if (c == '\n') {
		xxlineno += 1;
		xxcolno = 0;
    	xxbyteno = 0;
    } else {
        xxcolno++;
    	xxbyteno++;
    }
    /* only advance column for 1st byte in UTF-8 */
    if (0x80 <= (unsigned char)c && (unsigned char)c <= 0xBF && known_to_be_utf8){ 
    	xxcolno--;
	}

    if (c == '\t'){
		xxcolno = ((xxcolno + 7) & ~7);
	}
    
    R_ParseContextLine = xxlineno;    

    if ( KeepSource && GenerateCode && FunctionLevel > 0 ) {
		if(SourcePtr <  FunctionSource + MAXFUNSIZE){
		    *SourcePtr++ = c;
		}
		else {
			error(_("function is too long to keep source (at line %d)"), xxlineno);
		}
    }
    xxcharcount++;
    return c;
}

/**
 * Returns to the state previous to the call to xxgetc
 *
 * @return the character before
 */ 
static int xxungetc(int c) {
	
    /* this assumes that c was the result of xxgetc; if not, some edits will be needed */
    xxlineno = prevlines[prevpos];
    xxbyteno = prevbytes[prevpos];
    xxcolno  = prevcols[prevpos];
    prevpos = (prevpos + PUSHBACK_BUFSIZE - 1) % PUSHBACK_BUFSIZE;

    R_ParseContextLine = xxlineno;
    if ( KeepSource && GenerateCode && FunctionLevel > 0 ){
		SourcePtr--;
	}
    xxcharcount--;
    R_ParseContext[R_ParseContextLast] = '\0';
    
	/* precaution as to how % is implemented for < 0 numbers */
    R_ParseContextLast = (R_ParseContextLast + PARSE_CONTEXT_SIZE -1) % PARSE_CONTEXT_SIZE;
    if(npush >= PUSHBACK_BUFSIZE) return EOF;
    pushback[npush++] = c;
    return c;
}

/*}}}*/

/*{{{ srcref */
/**
 * extract information from the lloc location information and 
 * makes the srcref from it
 *
 * attach the srcfile as the "srcfile" attribute
 * set the class to "srcref"
 */
static SEXP makeSrcref(YYLTYPE *lloc, SEXP srcfile) {
    SEXP val;

    PROTECT(val = allocVector(INTSXP, 6));
    INTEGER(val)[0] = lloc->first_line;
    INTEGER(val)[1] = lloc->first_byte;
    INTEGER(val)[2] = lloc->last_line;
    INTEGER(val)[3] = lloc->last_byte;
    INTEGER(val)[4] = lloc->first_column;
    INTEGER(val)[5] = lloc->last_column;
    setAttrib(val, mkString("srcfile"), srcfile);
    setAttrib(val, R_ClassSymbol, mkString("srcref"));
    UNPROTECT(1);
    return val;
}

/**
 * attach the srcref
 * TODO : get a better understanding of what this is doing
 */
static SEXP attachSrcrefs(SEXP val, SEXP srcfile) {
    SEXP t, srval;
    int n;

    PROTECT(val);
    t = CDR(SrcRefs);
    srval = allocVector(VECSXP, length(t));
    for (n = 0 ; n < LENGTH(srval) ; n++, t = CDR(t))
	SET_VECTOR_ELT(srval, n, CAR(t));
    setAttrib(val, mkString("srcref"), srval);
    setAttrib(val, mkString("srcfile"), srcfile);
    UNPROTECT(1);
    SrcRefs = NULL;
    return val;
}
/*}}} */

/*{{{ Deal with formal arguments of functions*/
               
/**
 * Returns a NULL (R_NilValue) used for functions without arguments
 * f <- function(){}
 * 
 * @return a NULL
 */
static SEXP xxnullformal(){
    SEXP ans;
    PROTECT(ans = R_NilValue);
    return ans;
}

/**
 * first formal argument, not being associated to a value
 * f <- function( x ){}
 *
 * @param sym name of the symbol
 * @return
 */ 
static SEXP xxfirstformal0(SEXP sym){
    SEXP ans;
    UNPROTECT_PTR(sym);
    if (GenerateCode) {
		PROTECT(ans = FirstArg(R_MissingArg, sym));
    } else {
		PROTECT(ans = R_NilValue);
    }
	return ans;
}

/**
 * first formal argument with a value
 * f <- function(x=2){}
 * 
 * @param sym name of the formal argument
 * @param expr expression to use for the value of the formal argument
 * @return the new built formal argument list
 */
static SEXP xxfirstformal1(SEXP sym, SEXP expr){
    SEXP ans;
    if (GenerateCode){
		PROTECT(ans = FirstArg(expr, sym));
    } else { 
		PROTECT(ans = R_NilValue);
	}
    UNPROTECT_PTR(expr);
    UNPROTECT_PTR(sym);
    return ans;
}

/**
 * Adds another formal argument name without value
 * 
 * @param formlist the list of formal arguments so far
 * @param sym name of the new formal argument
 * @param lloc location information
 * @return the modified formals list
 */
static SEXP xxaddformal0(SEXP formlist, SEXP sym, YYLTYPE *lloc) {
	
    SEXP ans;
    if (GenerateCode) {
		CheckFormalArgs(formlist, sym, lloc);
		PROTECT(ans = NextArg(formlist, R_MissingArg, sym));
    }
    else {
		PROTECT(ans = R_NilValue);
	}
    UNPROTECT_PTR(sym);
    UNPROTECT_PTR(formlist);
    return ans;
}

/**
 * Adds another formal argument, with the value
 *
 * @param formlist previously existing formal argument list
 * @param sym name of the new argument to add
 * @param expr expression to use as the value of the new argument
 * @param lloc location information
 * @return the formal argument list, with the new argument added
 */
static SEXP xxaddformal1(SEXP formlist, SEXP sym, SEXP expr, YYLTYPE *lloc)
{
    SEXP ans;
    if (GenerateCode) {
		CheckFormalArgs(formlist, sym, lloc);
		PROTECT(ans = NextArg(formlist, expr, sym));
    }
    else {
		PROTECT(ans = R_NilValue);
	}
    UNPROTECT_PTR(expr);
    UNPROTECT_PTR(sym);
    UNPROTECT_PTR(formlist);
    return ans;
}


/**
 * Creates a formals argument list
 *
 * @param s the expression to use as the value of the formal argument
 * @param tag the name of the argument
 * @return the newly built formals argument list
 */
static SEXP FirstArg(SEXP s, SEXP tag){
    SEXP tmp;
    PROTECT(s);
    PROTECT(tag);
    PROTECT(tmp = NewList());
    tmp = GrowList(tmp, s);
    SET_TAG(CAR(tmp), tag);
    UNPROTECT(3);
    return tmp;
}

/**
 * Called to add a formal argument 
 *
 * @param l already existing formal argument list
 * @param s value of the argument
 * @param tag name of the arrgument
 */
static SEXP NextArg(SEXP l, SEXP s, SEXP tag) {
    PROTECT(tag);
    PROTECT(l);
    l = GrowList(l, s);
    SET_TAG(CAR(l), tag);
    UNPROTECT(2);
    return l;
} /*}}}*/

/*{{{ expression lists */

/**
 * Expression list
 * 
 * @param a1 the left brace
 * @param lloc location information for ??
 * @param a2 the expression list
 */
static SEXP xxexprlist(SEXP a1, YYLTYPE *lloc, SEXP a2) {
    SEXP ans;
    SEXP prevSrcrefs;

    EatLines = 0;
    if (GenerateCode) {
		SET_TYPEOF(a2, LANGSXP);
		SETCAR(a2, a1);
		if (SrcFile) {
		    PROTECT(prevSrcrefs = getAttrib(a2, mkString("srcref")));
		    REPROTECT(SrcRefs = Insert(SrcRefs, makeSrcref(lloc, SrcFile)), srindex);
		    PROTECT(ans = attachSrcrefs(a2, SrcFile));
		    REPROTECT(SrcRefs = prevSrcrefs, srindex);
		    /* SrcRefs got NAMED by being an attribute... */
		    SET_NAMED(SrcRefs, 0);
		    UNPROTECT_PTR(prevSrcrefs);
		} else {
		    PROTECT(ans = a2);
		}
    } else {
		PROTECT(ans = R_NilValue);
    }
	UNPROTECT_PTR(a2);
    return ans;
}

/**
 * Starts an expression list (after the left brace)
 * Creates a new list using NewList. 
 *
 * srcref records are added to the expression list
 *
 * @return the newly created expression list
 */
static SEXP xxexprlist0(void) {
    SEXP ans;
    if (GenerateCode) {
		PROTECT(ans = NewList());
		if (SrcFile) {
		    setAttrib(ans, mkString("srcref"), SrcRefs);
		    REPROTECT(SrcRefs = NewList(), srindex);
		}
    } else {
		PROTECT(ans = R_NilValue);
	}
    return ans;
}

/**
 * Creates the first expression in an expression list
 * 
 * @param expr the first expression
 * @param lloc location information
 * @return an expression list with one expression (given by expr)
 */
static SEXP xxexprlist1(SEXP expr, YYLTYPE *lloc){
    SEXP ans,tmp;
    if (GenerateCode) {
		PROTECT(tmp = NewList());
		if (SrcFile) {
		    setAttrib(tmp, mkString("srcref"), SrcRefs);
		    REPROTECT(SrcRefs = NewList(), srindex);
		    REPROTECT(SrcRefs = GrowList(SrcRefs, makeSrcref(lloc, SrcFile)), srindex);
		}
		PROTECT(ans = GrowList(tmp, expr));
		UNPROTECT_PTR(tmp);
    } else {
		PROTECT(ans = R_NilValue);
    }
	UNPROTECT_PTR(expr);
    return ans;
}

/**
 * Adds an expression to an already existing expression list
 *
 * @param exprlist the current expression list
 * @param expr the expression to add
 * @param lloc location information for the new expression
 * @return the modified expression list
 */
static SEXP xxexprlist2(SEXP exprlist, SEXP expr, YYLTYPE *lloc){
    SEXP ans;
    if (GenerateCode) {
		if (SrcFile){
			REPROTECT(SrcRefs = GrowList(SrcRefs, makeSrcref(lloc, SrcFile)), srindex);
		}
		PROTECT(ans = GrowList(exprlist, expr));
    } else {
		PROTECT(ans = R_NilValue);
	}
    UNPROTECT_PTR(expr);
    UNPROTECT_PTR(exprlist);
    return ans;
}
/*}}}*/

/*{{{ subscripts */

/**
 * Single or double subscripts
 *
 * @param a1 expression before the square bracket
 * @param a2 either one square bracket or two
 * @param a3 the content
 *
 * @note
 * This should probably use CONS rather than LCONS, but
 * it shouldn't matter and we would rather not meddle
 * See PR#7055 
 */
static SEXP xxsubscript(SEXP a1, SEXP a2, SEXP a3){
    SEXP ans;
    if (GenerateCode){
		PROTECT(ans = LCONS(a2, CONS(a1, CDR(a3))));
    } else {
		PROTECT(ans = R_NilValue);
	}
    UNPROTECT_PTR(a3);
    UNPROTECT_PTR(a1);
    return ans;
}


/*{{{ atomic subsets */
/**
 * Empty subset
 *
 * @return the subset
 */
static SEXP xxsub0(void){
    SEXP ans;
    if (GenerateCode){
		PROTECT(ans = lang2(R_MissingArg,R_NilValue));
    } else {
		PROTECT(ans = R_NilValue);
	}
    return ans;
}

/**
 * subset with one expression
 *
 * @param expr expression that is inside the subset
 * @param lloc location information for the expression
 * @return the subset
 */
static SEXP xxsub1(SEXP expr, YYLTYPE *lloc){
    SEXP ans;
    if (GenerateCode){
		PROTECT(ans = TagArg(expr, R_NilValue, lloc));
    } else {
		PROTECT(ans = R_NilValue);
    }
	UNPROTECT_PTR(expr);
    return ans;
}

/**
 * subset with a symbol or a character constant followed by the 
 * equal sign
 * 
 * examples: 
 * x[y=]
 * x['y'=]
 *
 * @param sym the symbol name (or character constant)
 * @param the location information of the symbol
 * @return the subset
 */
static SEXP xxsymsub0(SEXP sym, YYLTYPE *lloc){
    SEXP ans;
    if (GenerateCode){
		PROTECT(ans = TagArg(R_MissingArg, sym, lloc));
    } else {
		PROTECT(ans = R_NilValue);
	}
    UNPROTECT_PTR(sym);
    return ans;
}

/**
 * Subset with exactly one expression. symbol name = expression
 *
 * examples: 
 * x[ y = 2 ]
 * x[ 'y' = 2 ]
 * 
 * @param sym symbol name (or character constant)
 * @param expr expression after the equal sign
 * @return the subset
 */
static SEXP xxsymsub1(SEXP sym, SEXP expr, YYLTYPE *lloc){
    SEXP ans;
    if (GenerateCode){
		PROTECT(ans = TagArg(expr, sym, lloc));
    } else {
		PROTECT(ans = R_NilValue);
	}
    UNPROTECT_PTR(expr);
    UNPROTECT_PTR(sym);
    return ans;
}

/**
 * Subset where the lhs of the subset is NULL and there is no rhs
 *
 * examples: 
 * x[ NULL = ]
 *
 * @param lloc location information for the NULL
 * @return the subset
 */
static SEXP xxnullsub0(YYLTYPE *lloc){
    SEXP ans;
    UNPROTECT_PTR(R_NilValue);
    if (GenerateCode){
		PROTECT(ans = TagArg(R_MissingArg, install("NULL"), lloc));
    } else {
		PROTECT(ans = R_NilValue);
	}
    return ans;
}

/**
 * Subset where NULL is the lhs and there is a rhs
 * 
 * examples: 
 * x[ NULL = 2 ]
 *
 * @param expr expression to use at the rhs of the subset
 * @param lloc location information for the expression
 * @return the subset
 */
static SEXP xxnullsub1(SEXP expr, YYLTYPE *lloc) {
    SEXP ans = install("NULL");
    UNPROTECT_PTR(R_NilValue);
    if (GenerateCode){
		PROTECT(ans = TagArg(expr, ans, lloc));
    } else {
		PROTECT(ans = R_NilValue);
    }
	UNPROTECT_PTR(expr);
    return ans;
}
/*}}}*/

/*{{{ subset lists */
/**
 * Subset list with exactly one subset
 * 
 * @param sub the subset to use
 * @return the subset list with this subset
 */ 
static SEXP xxsublist1(SEXP sub){
    SEXP ans;
    if (GenerateCode){
		PROTECT(ans = FirstArg(CAR(sub),CADR(sub)));
    } else {
		PROTECT(ans = R_NilValue);
	}
    UNPROTECT_PTR(sub);
    return ans;
}

/**
 * Subset list with two or more subsets
 * 
 * @param sublist subset list so far
 * @param new subset to append
 * @return the subset list with the new subset added
 */ 
static SEXP xxsublist2(SEXP sublist, SEXP sub){
    SEXP ans;
    if (GenerateCode){
		PROTECT(ans = NextArg(sublist, CAR(sub), CADR(sub)));
    } else {
		PROTECT(ans = R_NilValue);
	}
    UNPROTECT_PTR(sub);
    UNPROTECT_PTR(sublist);
    return ans;
}
/*}}}*/
/*}}}*/

/*{{{ Conditional things */
/**
 * Expression with round brackets
 *
 * This function has the side effect of setting the "EatLines"
 * variable to 1
 *
 * @param expr the expression 
 * @return the expression it was passed
 * 
 */ 
static SEXP xxcond(SEXP expr){
    EatLines = 1;
    return expr;
}

/**
 * expression within a if statement. 
 * 
 * This function has the side effect of setting the "EatLines"
 * variable to 1
 *
 * @param expr the expression inside the if call
 * @return the same expression
 */
static SEXP xxifcond(SEXP expr){
    EatLines = 1;
    return expr;
}

/**
 * if( cond ) expr
 *
 * @param ifsym the if expression
 * @param cond the content of condition
 * @param expr the expression in the "body" of the if
 * @return the expression surrounded by the if condition 
 */
static SEXP xxif(SEXP ifsym, SEXP cond, SEXP expr){
    SEXP ans;
    if (GenerateCode){ 
		PROTECT(ans = lang3(ifsym, cond, expr));
    } else {
		PROTECT(ans = R_NilValue);
	}
    UNPROTECT_PTR(expr);
    UNPROTECT_PTR(cond);
    return ans;
}

/**
 * if( cond ) ifexpr else elseexpr
 * 
 * @param ifsym the if symbol
 * @param cond the condition
 * @param ifexpr the expression when the condition is TRUE
 * @param elseexpr the expressionn when the condition is FALSE
 * 
 */
static SEXP xxifelse(SEXP ifsym, SEXP cond, SEXP ifexpr, SEXP elseexpr){
    SEXP ans;
    if( GenerateCode){
		PROTECT(ans = lang4(ifsym, cond, ifexpr, elseexpr));
	} else {
		PROTECT(ans = R_NilValue);
	}
    UNPROTECT_PTR(elseexpr);
    UNPROTECT_PTR(ifexpr);
    UNPROTECT_PTR(cond);
    return ans;
}

/**
 * content of a for loop 
 *
 * rule: 
 * '(' SYMBOL IN expr ')' 		{ $$ = xxforcond($2,$4); }
 *
 * @param sym the symbol used at the left of the in
 * @param expr the expression used at the right of the in
 * @return the content of the round bracket part of the for loop
 */
static SEXP xxforcond(SEXP sym, SEXP expr){
    SEXP ans;
    EatLines = 1;
    if (GenerateCode)
	PROTECT(ans = LCONS(sym, expr));
    else
	PROTECT(ans = R_NilValue);
    UNPROTECT_PTR(expr);
    UNPROTECT_PTR(sym);
    return ans;
}
/*}}}*/

/*{{{ Loops */
/** 
 * for loop
 * 
 * @param forsym the for symbol
 * @param forcond content of the condition (see xxforcond)
 * @param body body of the for loop
 * @return the whole for loop expression
 */
static SEXP xxfor(SEXP forsym, SEXP forcond, SEXP body){
    SEXP ans;
    if (GenerateCode){
		PROTECT(ans = lang4(forsym, CAR(forcond), CDR(forcond), body));
    } else {
		PROTECT(ans = R_NilValue);
	}
    UNPROTECT_PTR(body);
    UNPROTECT_PTR(forcond);
    return ans;
}

/**
 * while loop
 * 
 * @param whilesym while symbol
 * @param cond condition of the while
 * @param body body of the while loop
 * @return the whole while expression
 */
static SEXP xxwhile(SEXP whilesym, SEXP cond, SEXP body){
    SEXP ans;
    if (GenerateCode){
		PROTECT(ans = lang3(whilesym, cond, body));
	} else {
		PROTECT(ans = R_NilValue);
	}
    UNPROTECT_PTR(body);
    UNPROTECT_PTR(cond);
    return ans;
}

/**
 * the repeat loop
 * 
 * @param repeatsym the repeat symbol
 * @param body the body of the repeat
 * @return the whole repeat expression
 */
static SEXP xxrepeat(SEXP repeatsym, SEXP body){
    SEXP ans;
    if (GenerateCode){
		PROTECT(ans = lang2(repeatsym, body));
    } else {
		PROTECT(ans = R_NilValue);
	}
    UNPROTECT_PTR(body);
    return ans;
}

/** 
 * next or break
 * 
 * @param keyword one of next or break
 * @return the keyword (passed through lang1)
 */ 
static SEXP xxnxtbrk(SEXP keyword){
    if (GenerateCode){
		PROTECT(keyword = lang1(keyword));
	} else {
		PROTECT(keyword = R_NilValue);
	}
    return keyword;
}
/*}}}*/

/*{{{ Functions */
/** 
 * function call
 * 
 * @param expr expression used as the calling function
 * @param args list of arguments
 * @return the whole function call
 */
static SEXP xxfuncall(SEXP expr, SEXP args){
    SEXP ans, sav_expr = expr;
    if(GenerateCode) {
		if (isString(expr)){
		    expr = install(CHAR(STRING_ELT(expr, 0)));
		}
		PROTECT(expr);
		if (length(CDR(args)) == 1 && CADR(args) == R_MissingArg && TAG(CDR(args)) == R_NilValue ){
		    ans = lang1(expr);
		} else {
		    ans = LCONS(expr, CDR(args));
		}
		UNPROTECT(1);
		PROTECT(ans);
    } else {
		PROTECT(ans = R_NilValue);
    }
    UNPROTECT_PTR(args);
    UNPROTECT_PTR(sav_expr);
    return ans;
}

/** 
 * Function definition
 *
 * @param fname the name of the function
 * @param formals the list of formal arguments
 * @param body the body of the function
 * @return the expression containing the function definition
 */
static SEXP xxdefun(SEXP fname, SEXP formals, SEXP body){

    SEXP ans;
    SEXP source;

    if (GenerateCode) {
		if (!KeepSource){ 
			PROTECT(source = R_NilValue);
		} else {
	    	unsigned char *p, *p0, *end;
	    	int lines = 0, nc;
        	
	    	/*  If the function ends with an endline comment,  e.g.
        	
			function()
			    print("Hey") # This comment
        	
			we need some special handling to keep it from getting
			chopped off. Normally, we will have read one token too
			far, which is what xxcharcount and xxcharsave keeps
			track of.
        	
	    	*/
	    	end = SourcePtr - (xxcharcount - xxcharsave);
	    	
			/* FIXME: this should be whitespace */
	    	for (p = end ; p < SourcePtr && (*p == ' ' || *p == '\t') ; p++) ;
	    	if (*p == '#') {
				while (p < SourcePtr && *p != '\n'){
				    p++;
				}
				end = p;
	    	}
        	
	    	for (p = FunctionStart[FunctionLevel]; p < end ; p++){
				if (*p == '\n') {
					lines++;
				}
			}
	    	if ( *(end - 1) != '\n' ){
				lines++;
			}
	    	PROTECT(source = allocVector(STRSXP, lines));
	    	p0 = FunctionStart[FunctionLevel];
	    	lines = 0;
	    	for (p = FunctionStart[FunctionLevel]; p < end ; p++){
				if (*p == '\n' || p == end - 1) {
				    cetype_t enc = CE_NATIVE;
				    nc = p - p0;
				    if (*p != '\n') {
						nc++;
					}
				    if(known_to_be_latin1) {
						enc = CE_LATIN1;
					} else if(known_to_be_utf8) {
						enc = CE_UTF8;
					}
				    SET_STRING_ELT(source, lines++,
						   mkCharLenCE((char *)p0, nc, enc));
				    p0 = p + 1;
				}
			}
			/* PrintValue(source); */
		}
		PROTECT(ans = lang4(fname, CDR(formals), body, source));
		UNPROTECT_PTR(source);
    }
    else {
		PROTECT(ans = R_NilValue);
	}
    UNPROTECT_PTR(body);
    UNPROTECT_PTR(formals);
    FunctionLevel--;
    return ans;
}
/*}}}*/

/*{{{ Operators unary and binary */
/**
 * Unary operator
 *
 * @param op operator
 * @param arg expression used as the argument of the operator
 * @return the operator applied to the expression
 */
static SEXP xxunary(SEXP op, SEXP arg){
    SEXP ans;
    if (GenerateCode){
		PROTECT(ans = lang2(op, arg));
    } else {
		PROTECT(ans = R_NilValue);
	}
    UNPROTECT_PTR(arg);
    return ans;
}

/**
 * Binary operator
 * 
 * @param n1 expression before the binary operator
 * @param n2 the binary operator
 * @param n3 expression after the binary operator
 * @return the expression n1 n2 n3
 */
static SEXP xxbinary(SEXP n1, SEXP n2, SEXP n3){
    SEXP ans;
    if (GenerateCode){
		PROTECT(ans = lang3(n1, n2, n3));
    } else {
		PROTECT(ans = R_NilValue);
	}
    UNPROTECT_PTR(n2);
    UNPROTECT_PTR(n3);
    return ans;
}
/*}}}*/

/**
 * Content of round brackets
 *
 * @param n1 the round bracket
 * @param n2 the expression inside
 * @return the n2 expression wrapped in brackets
 */
static SEXP xxparen(SEXP n1, SEXP n2){
    SEXP ans;
    if (GenerateCode){
		PROTECT(ans = lang2(n1, n2));
	} else {
		PROTECT(ans = R_NilValue);
	}
    UNPROTECT_PTR(n2);
    return ans;
}

/**
 * Returns the value of the expression, called after '\n' or ';'
 *
 * @param v 
 * @param k 
 * @param lloc location information
 * @return 
 */        
static int xxvalue(SEXP v, int k, YYLTYPE *lloc) {
    if (k > 2) {
		if (SrcFile){
		    REPROTECT(SrcRefs = GrowList(SrcRefs, makeSrcref(lloc, SrcFile)), srindex);
		}
		UNPROTECT_PTR(v);
    }
    R_CurrentExpr = v;
    return k;
}

static SEXP mkString2(const char *s, int len){
    SEXP t;
    cetype_t enc = CE_NATIVE;

    if(known_to_be_latin1) {
		enc= CE_LATIN1;
	} else if(known_to_be_utf8) {
		enc = CE_UTF8;
	}

    PROTECT(t = allocVector(STRSXP, 1));
    SET_STRING_ELT(t, 0, mkCharLenCE(s, len, enc));
    UNPROTECT(1);
    return t;
}
/*}}} xx */

/*{{{ IfPush and ifpop */
static void IfPush(void) {
    if (*contextp==LBRACE || *contextp=='[' || *contextp=='('  || *contextp == 'i') {
		if(contextp - contextstack >= CONTEXTSTACK_SIZE){
		    error(_("contextstack overflow"));
		}
		*++contextp = 'i';
    }

}

static void ifpop(void){
    if (*contextp=='i')
	*contextp-- = 0;
}

/*}}}*/

/*{{{ function to deal with characters */
/**
 * Looks at the type of the next character
 *
 * @return 1 if the next character is a digit, 2 otherwise
 */
static int typeofnext(void) {
    int k, c;

    c = xxgetc();
    if (isdigit(c)){
		k = 1; 
	} else {
		k = 2;
	}
    xxungetc(c);
    return k;
}

/** 
 * Moves forward one character, checks that we get what we expect.
 * if not return 0 and move back to where it started
 * 
 * @param expect the character that is expected next
 * @return 1 if the the next character is the one we expect, otherwise 
 *    go back and return 0
 */
static int nextchar(int expect){
    int c = xxgetc();
    if (c == expect){
		return 1;
    } else {
		xxungetc(c);
	}
    return 0;
}


/* Note that with interactive use, EOF cannot occur inside */
/* a comment.  However, semicolons inside comments make it */
/* appear that this does happen.  For this reason we use the */
/* special assignment EndOfFile=2 to indicate that this is */
/* going on.  This is detected and dealt with in Parse1Buffer. */

/**
 * Flush away comments. Keep going to the next character until the 
 * end of the line
 * 
 */
static int SkipComment(void){
    int c;
    while ((c = xxgetc()) != '\n' && c != R_EOF) ;
    if (c == R_EOF) {
		EndOfFile = 2;
	}
    return c;
}

/**
 * Converts to a numeric value
 */ 
static int NumericValue(int c) {
    int seendot = (c == '.');
    int seenexp = 0;
    int last = c;
    int nd = 0;
    int asNumeric = 0;

    DECLARE_YYTEXT_BUFP(yyp);
    YYTEXT_PUSH(c, yyp);
    /* We don't care about other than ASCII digits */
    while (isdigit(c = xxgetc()) || c == '.' || c == 'e' || c == 'E' || c == 'x' || c == 'X' || c == 'L'){
		if (c == 'L') /* must be at the end.  Won't allow 1Le3 (at present). */
		    break;

		if (c == 'x' || c == 'X') {
		    if (last != '0') break;
		    YYTEXT_PUSH(c, yyp);
		    while(isdigit(c = xxgetc()) || ('a' <= c && c <= 'f') || ('A' <= c && c <= 'F') || c == '.') {
				YYTEXT_PUSH(c, yyp);
				nd++;
		    }
		    if (nd == 0) return ERROR;
		    if (c == 'p' || c == 'P') {
				YYTEXT_PUSH(c, yyp);
				c = xxgetc();
				if (!isdigit(c) && c != '+' && c != '-') return ERROR;
				if (c == '+' || c == '-') {
				    YYTEXT_PUSH(c, yyp);
				    c = xxgetc();
				}
				for(nd = 0; isdigit(c); c = xxgetc(), nd++){
				    YYTEXT_PUSH(c, yyp);
				}
				if (nd == 0) return ERROR;
		    }
		    break;
		}
		
		if (c == 'E' || c == 'e') {
		    if (seenexp)
				break;
		    seenexp = 1;
		    seendot = seendot == 1 ? seendot : 2;
		    YYTEXT_PUSH(c, yyp);
		    c = xxgetc();
		    if (!isdigit(c) && c != '+' && c != '-') return ERROR;
		    if (c == '+' || c == '-') {
				YYTEXT_PUSH(c, yyp);
				c = xxgetc();
				if (!isdigit(c)) return ERROR;
		    }
		}
		
		if (c == '.') {
		    if (seendot)
			break;
		    seendot = 1;
		}
		
		YYTEXT_PUSH(c, yyp);
		last = c;
    }
	
    YYTEXT_PUSH('\0', yyp);
    /* Make certain that things are okay. */
    if(c == 'L') {
		double a = R_atof(yytext);
		int b = (int) a;
		/* We are asked to create an integer via the L, so we check that the
		   double and int values are the same. If not, this is a problem and we
		   will not lose information and so use the numeric value.
		*/
		if(a != (double) b) {
		    if(GenerateCode) {
				if(seendot == 1 && seenexp == 0){
				    warning(_("integer literal %sL contains decimal; using numeric value"), yytext);
				} else {
				    warning(_("non-integer value %s qualified with L; using numeric value"), yytext);
				}
		    }
		    asNumeric = 1;
		    seenexp = 1;
		}
    }

    if(c == 'i') {
		yylval = GenerateCode ? mkComplex(yytext) : R_NilValue;
    } else if(c == 'L' && asNumeric == 0) {
		if(GenerateCode && seendot == 1 && seenexp == 0)
		    warning(_("integer literal %sL contains unnecessary decimal point"), yytext);
		yylval = GenerateCode ? mkInt(yytext) : R_NilValue;
#if 0  /* do this to make 123 integer not double */
    } else if(!(seendot || seenexp)) {
		if(c != 'L') xxungetc(c);
		if (GenerateCode) {
		    double a = R_atof(yytext);
		    int b = (int) a;
		    yylval = (a != (double) b) ? mkFloat(yytext) : mkInt(yytext);
		} else yylval = R_NilValue;
#endif
    } else {
		if(c != 'L')
		    xxungetc(c);
		yylval = GenerateCode ? mkFloat(yytext) : R_NilValue;
    }

    PROTECT(yylval);
    return NUM_CONST;
}

/**
 * Skips a space
 */ 
static int SkipSpace(void) {
    int c;

#ifdef Win32
    if(!mbcslocale) { /* 0xa0 is NBSP in all 8-bit Windows locales */
		while ((c = xxgetc()) == ' ' || c == '\t' || c == '\f' || (unsigned int) c == 0xa0) ;
		return c;
    } else {
		int i, clen;
		wchar_t wc;
		while (1) {
		    c = xxgetc();
		    if (c == ' ' || c == '\t' || c == '\f') continue;
		    if (c == '\n' || c == R_EOF) break;
		    if ((unsigned int) c < 0x80) break;
		    clen = mbcs_get_next(c, &wc);  /* always 2 */
		    if(! Ri18n_iswctype(wc, Ri18n_wctype("blank")) ) break;
		    for(i = 1; i < clen; i++) c = xxgetc();
		}
		return c;
    }
#endif

#if defined(SUPPORT_MBCS) && defined(__STDC_ISO_10646__)
    if(mbcslocale) { /* wctype functions need Unicode wchar_t */
		int i, clen;
		wchar_t wc;
		while (1) {
		    c = xxgetc();
		    if (c == ' ' || c == '\t' || c == '\f') continue;
		    if (c == '\n' || c == R_EOF) break;
		    if ((unsigned int) c < 0x80) break;
		    clen = mbcs_get_next(c, &wc);
		    if(! Ri18n_iswctype(wc, Ri18n_wctype("blank")) ) break;
		    for(i = 1; i < clen; i++) c = xxgetc();
		}
    } else
#endif
	while ((c = xxgetc()) == ' ' || c == '\t' || c == '\f') ;
    return c;
}
/*}}}*/

/*{{{ Special Symbols */
/* Syntactic Keywords + Symbolic Constants */
struct {
    char *name;
    int token;
}
static keywords[] = {
    { "NULL",	    NULL_CONST },
    { "NA",	    NUM_CONST  },
    { "TRUE",	    NUM_CONST  },
    { "FALSE",	    NUM_CONST  },
    { "Inf",	    NUM_CONST  },
    { "NaN",	    NUM_CONST  },
    { "NA_integer_", NUM_CONST  },
    { "NA_real_",    NUM_CONST  },
    { "NA_character_", NUM_CONST  },
    { "NA_complex_", NUM_CONST  },
    { "function",   FUNCTION   },
    { "while",	    WHILE      },
    { "repeat",	    REPEAT     },
    { "for",	    FOR	       },
    { "if",	    IF	       },
    { "in",	    IN	       },
    { "else",	    ELSE       },
    { "next",	    NEXT       },
    { "break",	    BREAK      },
    { "...",	    SYMBOL     },
    { 0,	    0	       }
};
/*}}}*/

/*{{{ Keyword lookup */
/**
 * 
 * @note KeywordLookup has side effects, it sets yylval
 */ 
static int KeywordLookup(const char *s) {
    int i;
    for (i = 0; keywords[i].name; i++) {
		if (strcmp(keywords[i].name, s) == 0) {
		    switch (keywords[i].token) {
		    	case NULL_CONST:
					PROTECT(yylval = R_NilValue);
					break;
		    	case NUM_CONST:
					if(GenerateCode) {
					    switch(i) {
					    	case 1:
								PROTECT(yylval = mkNA());
								break;
					    	case 2:
								PROTECT(yylval = mkTrue());
								break;
					    	case 3:
								PROTECT(yylval = mkFalse());
								break;
					    	case 4:
								PROTECT(yylval = allocVector(REALSXP, 1));
								REAL(yylval)[0] = R_PosInf;
								break;
					    	case 5:
								PROTECT(yylval = allocVector(REALSXP, 1));
								REAL(yylval)[0] = R_NaN;
								break;
					    	case 6:
								PROTECT(yylval = allocVector(INTSXP, 1));
								INTEGER(yylval)[0] = NA_INTEGER;
								break;
					    	case 7:
								PROTECT(yylval = allocVector(REALSXP, 1));
								REAL(yylval)[0] = NA_REAL;
								break;
					    	case 8:
								PROTECT(yylval = allocVector(STRSXP, 1));
								SET_STRING_ELT(yylval, 0, NA_STRING);
								break;
					    	case 9:
								PROTECT(yylval = allocVector(CPLXSXP, 1));
								COMPLEX(yylval)[0].r = COMPLEX(yylval)[0].i = NA_REAL;
								break;
					    }
					} else {
					    PROTECT(yylval = R_NilValue);
					}
					break;
		    	case FUNCTION:
		    	case WHILE:
		    	case REPEAT:
		    	case FOR:
		    	case IF:
		    	case NEXT:
		    	case BREAK:
					yylval = install(s);
					break;
		    	case IN:
		    	case ELSE:
					break;
		    	case SYMBOL:
					PROTECT(yylval = install(s));
					break;
		    }
		    return keywords[i].token;
		}
    }
    return 0;
}
/*}}}*/

/*{{{ mk* functions */
/**
 * Makes a COMPLEX (CPLXSXP) from the character string
 *
 * @param s the character string to convert to a complex
 * @param GenerateCode if true some code is generated
 */
SEXP mkComplex(const char *s ) {
    SEXP t = R_NilValue;
    double f;
	/* FIXME: make certain the value is legitimate. */
    f = R_atof(s); 

    if(GenerateCode) {
       t = allocVector(CPLXSXP, 1);
       COMPLEX(t)[0].r = 0;
       COMPLEX(t)[0].i = f;
    }

    return t;
}

/**
 * Makes a missing logical value (LGLSXP, with NA_LOGICAL)
 */
SEXP mkNA(void){
    SEXP t = allocVector(LGLSXP, 1);
    LOGICAL(t)[0] = NA_LOGICAL;
    return t;
}

/**
 * Makes a TRUE logical value (LGLSXP, with 1)
 */
SEXP mkTrue(void){
    SEXP s = allocVector(LGLSXP, 1);
    LOGICAL(s)[0] = 1;
    return s;
}

/**
 * Makes a FALSE logical value (LGLSXP, with 0)
 */
SEXP mkFalse(void){
    SEXP s = allocVector(LGLSXP, 1);
    LOGICAL(s)[0] = 0;
    return s;
}

/**
 * Makes a float (ScalarReal) from the string
 */
SEXP mkFloat(const char *s) {
    return ScalarReal(R_atof(s));
}

/**
 * Makes a int (ScalarInteger) from ths string
 */
SEXP mkInt(const char *s){
    double f = R_atof(s);  /* or R_strtol? */
    return ScalarInteger((int) f);
}
/*}}}*/

/*{{{ TagArg */
/**
 * tags
 * Report an error when incorrect tag (using first line)
 */
static SEXP TagArg(SEXP arg, SEXP tag, YYLTYPE *lloc) {
    switch (TYPEOF(tag)) {
    	case STRSXP:
			tag = install(translateChar(STRING_ELT(tag, 0)));
    	case NILSXP:
    	case SYMSXP:
			return lang2(arg, tag);
    	default:
			error(_("incorrect tag type at line %d"), lloc->first_line); return R_NilValue/* -Wall */;
    }
}
/*}}}*/

/*{{{ arg */
/* Stretchy List Structures : Lists are created and grown using a special */
/* dotted pair.  The CAR of the list points to the last cons-cell in the */
/* list and the CDR points to the first.  The list can be extracted from */
/* the pair by taking its CDR, while the CAR gives fast access to the end */
/* of the list. */

/**
 * Creates a stretchy-list dotted pair
 */ 
static SEXP NewList(void) {
    SEXP s = CONS(R_NilValue, R_NilValue);
    SETCAR(s, s);
    return s;
}

/**
 * Add a new element at the __end__ of a stretchy list
 * 
 * @param l stretchy list to expand
 * @param s element to add at the __end__ of the list
 * @return 
 */ 
static SEXP GrowList(SEXP l, SEXP s) {
    SEXP tmp;
    PROTECT(s);
    tmp = CONS(s, R_NilValue);
    UNPROTECT(1);
    SETCDR(CAR(l), tmp);
    SETCAR(l, tmp);
    return l;
}

/**
 * Insert a new element at the __head__ of a stretchy list
 * 
 * @param l stretchy list in which we want to insert s
 * @param s element to add to l
 * @return the stretchy list l appended by s
 */ 
static SEXP Insert(SEXP l, SEXP s){
    SEXP tmp;
    PROTECT(s);
    tmp = CONS(s, CDR(l));
    UNPROTECT(1);
    SETCDR(l, tmp);
    return l;
}

/*}}} */

/*{{{ lexer */

/*{{{ yyerror */
/**
 * The error reporting function. calls whenever bison sees a token
 * that does not fit any parser rule
 *
 * @param s the error message 
 */
static void yyerror(char *s) {
    static const char *const yytname_translations[] =
    {
    /* the left column are strings coming from bison, the right
       column are translations for users.
       The first YYENGLISH from the right column are English to be translated,
       the rest are to be copied literally.  The #if 0 block below allows xgettext
       to see these.
    */
#define YYENGLISH 8
	"$undefined",	"input",
	"END_OF_INPUT",	"end of input",
	"ERROR",	"input",
	"STR_CONST",	"string constant",
	"NUM_CONST",	"numeric constant",
	"SYMBOL",	"symbol",
	"LEFT_ASSIGN",	"assignment",
	"'\\n'",	"end of line",
	"NULL_CONST",	"'NULL'",
	"FUNCTION",	"'function'",
	"EQ_ASSIGN",	"'='",
	"RIGHT_ASSIGN",	"'->'",
	"LBB",		"'[['",
	"FOR",		"'for'",
	"IN",		"'in'",
	"IF",		"'if'",
	"ELSE",		"'else'",
	"WHILE",	"'while'",
	"NEXT",		"'next'",
	"BREAK",	"'break'",
	"REPEAT",	"'repeat'",
	"GT",		"'>'",
	"GE",		"'>='",
	"LT",		"'<'",
	"LE",		"'<='",
	"EQ",		"'=='",
	"NE",		"'!='",
	"AND",		"'&'",
	"OR",		"'|'",
	"AND2",		"'&&'",
	"OR2",		"'||'",
	"NS_GET",	"'::'",
	"NS_GET_INT",	"':::'",
	0
    };
    static char const yyunexpected[] = "syntax error, unexpected ";
    static char const yyexpecting[] = ", expecting ";
    char *expecting;
#if 0
 /* these are just here to trigger the internationalization */
    _("input");
    _("end of input");
    _("string constant");
    _("numeric constant");
    _("symbol");
    _("assignment");
    _("end of line");
#endif

    R_ParseError     = yylloc.first_line;
    R_ParseErrorCol  = yylloc.first_column;
    R_ParseErrorFile = SrcFile;

    if (!strncmp(s, yyunexpected, sizeof yyunexpected -1)) {
		int i;
		/* Edit the error message */
		expecting = strstr(s + sizeof yyunexpected -1, yyexpecting);
		if (expecting) {
			*expecting = '\0';
		}
		for (i = 0; yytname_translations[i]; i += 2) {
		    if (!strcmp(s + sizeof yyunexpected - 1, yytname_translations[i])) {
				sprintf(R_ParseErrorMsg, _("unexpected %s"),
				    i/2 < YYENGLISH ? _(yytname_translations[i+1])
						    : yytname_translations[i+1]);
				return;
		    }
		}
		sprintf(R_ParseErrorMsg, _("unexpected %s"), s + sizeof yyunexpected - 1);
    } else {
		strncpy(R_ParseErrorMsg, s, PARSE_ERROR_SIZE - 1);
    }
}
/*}}}*/

/*{{{ checkFormalArgs */
/**
 * checking formal arguments. Checks that the _new argument name
 * is not already used in the formal argument list. Generates
 * an error in that case.
 * 
 * Reports an error using the first line
 * @param formlist formal arguments list
 * @param _new name of a new symbol that is to be added to the 
 *        list of arguments
 * @param lloc location information
 * 
 */
static void CheckFormalArgs(SEXP formlist, SEXP _new, YYLTYPE *lloc) {
    while (formlist != R_NilValue) {
		if (TAG(formlist) == _new) {
		    error(_("Repeated formal argument '%s' on line %d"), CHAR(PRINTNAME(_new)),
									 lloc->first_line);
		}
		formlist = CDR(formlist);
    }
}
/*}}}*/



/* Strings may contain the standard ANSI escapes and octal */
/* specifications of the form \o, \oo or \ooo, where 'o' */
/* is an octal digit. */

#define STEXT_PUSH(c) do {                  \
	unsigned int nc = bp - stext;       \
	if (nc >= nstext - 1) {             \
	    char *old = stext;              \
	    nstext *= 2;                    \
	    stext = malloc(nstext);         \
	    if(!stext) error(_("unable to allocate buffer for long string at line %d"), xxlineno);\
	    memmove(stext, old, nc);        \
	    if(old != st0) free(old);	    \
	    bp = stext+nc; }		    \
	*bp++ = (c);                        \
} while(0)
	
/*{{{ mkStringUTF8 */
#ifdef USE_UTF8_IF_POSSIBLE
#define WTEXT_PUSH(c) do { if(wcnt < 1000) wcs[wcnt++] = c; } while(0)
 
/**
 * Turns the string into UTF-8
 *
 * @param wcs 
 * @param cnt FALSE if the quote character is ' or ", TRUE otherwise
 * @return the string as utf-8
 */
static SEXP mkStringUTF8(const wchar_t *wcs, int cnt) {
    SEXP t;
    char *s;
    int nb;

/* NB: cnt includes the terminator */
#ifdef Win32
    nb = cnt*4; /* UCS-2/UTF-16 so max 4 bytes per wchar_t */
#else
    nb = cnt*6;
#endif
    s = alloca(nb);
    R_CheckStack();
    memset(s, 0, nb); /* safety */
    wcstoutf8(s, wcs, nb);
    PROTECT(t = allocVector(STRSXP, 1));
    SET_STRING_ELT(t, 0, mkCharCE(s, CE_UTF8));
    UNPROTECT(1);
    return t;
}
#else
#define WTEXT_PUSH(c)
#endif
/*}}}*/

/*{{{ CTEXT_PUSH and CTEXT_POP */
#define CTEXT_PUSH(c) do { \
	if (ct - currtext >= 1000) {memmove(currtext, currtext+100, 901); memmove(currtext, "... ", 4); ct -= 100;} \
	*ct++ = (c); \
} while(0)
#define CTEXT_POP() ct--
/*}}}*/

/*{{{ StringValue */

/**
 * Returns the string value
 * 
 * @param c the quote character used to start the string
 * @param forSymbol 
 * @param the parser state after consuming all characters
 */
static int StringValue(int c, Rboolean forSymbol) {
	
    int quote = c;
    int have_warned = 0;
    char currtext[1010], *ct = currtext;
    char st0[MAXELTSIZE];
    unsigned int nstext = MAXELTSIZE;
    char *stext = st0, *bp = st0;

#ifdef USE_UTF8_IF_POSSIBLE
    int wcnt = 0;
    wchar_t wcs[1001];
    Rboolean use_wcs = FALSE;
#endif

    while ((c = xxgetc()) != R_EOF && c != quote) {
		CTEXT_PUSH(c);
		if (c == '\n') {
		    xxungetc(c);
		    /* Fix by Mark Bravington to allow multiline strings
		     * by pretending we've seen a backslash. Was:
		     * return ERROR;
		     */
		    c = '\\';
		}
		
		if (c == '\\') {
		    c = xxgetc(); CTEXT_PUSH(c);
		    if ('0' <= c && c <= '8') { 
				int octal = c - '0';
				if ('0' <= (c = xxgetc()) && c <= '8') {
				    CTEXT_PUSH(c);
				    octal = 8 * octal + c - '0';
				    if ('0' <= (c = xxgetc()) && c <= '8') {
						CTEXT_PUSH(c);
						octal = 8 * octal + c - '0';
				    } else {
						xxungetc(c);
						CTEXT_POP();
				    }
				} else {
				    xxungetc(c);
				    CTEXT_POP();
				}
				c = octal;
		    }
		    else if(c == 'x') {
				int val = 0; int i, ext;
				for(i = 0; i < 2; i++) {
				    c = xxgetc(); CTEXT_PUSH(c);
				    if(c >= '0' && c <= '9') ext = c - '0';
				    else if (c >= 'A' && c <= 'F') ext = c - 'A' + 10;
				    else if (c >= 'a' && c <= 'f') ext = c - 'a' + 10;
				    else {
						xxungetc(c);
						CTEXT_POP();
						if (i == 0) { /* was just \x */
						    if(GenerateCode && R_WarnEscapes) {
								have_warned++;
								warningcall(R_NilValue, _("'\\x' used without hex digits"));
						    }
						    val = 'x';
						}
						break;
				    }
				    val = 16*val + ext;
				}
				c = val;
		    } else if(c == 'u') {
#ifndef SUPPORT_MBCS
				error(_("\\uxxxx sequences not supported (line %d)"), xxlineno);
#else
				unsigned int val = 0; int i, ext; size_t res;
				char buff[MB_CUR_MAX+1]; /* could be variable, and hence not legal C90 */
				Rboolean delim = FALSE;
				if((c = xxgetc()) == '{') {
				    delim = TRUE;
				    CTEXT_PUSH(c);
				} else {
					xxungetc(c);
				}
				for(i = 0; i < 4; i++) {
				    c = xxgetc(); CTEXT_PUSH(c);
				    if(c >= '0' && c <= '9') ext = c - '0';
				    else if (c >= 'A' && c <= 'F') ext = c - 'A' + 10;
				    else if (c >= 'a' && c <= 'f') ext = c - 'a' + 10;
				    else {
						xxungetc(c);
						CTEXT_POP();
						if (i == 0) { /* was just \x */
						    if(GenerateCode && R_WarnEscapes) {
								have_warned++;
								warningcall(R_NilValue, _("\\u used without hex digits"));
						    }
						    val = 'u';
						}
						break;
				    }
				    val = 16*val + ext;
				}
				if(delim) {
				    if((c = xxgetc()) != '}')
					error(_("invalid \\u{xxxx} sequence (line %d)"), xxlineno);
				    else CTEXT_PUSH(c);
				}
				WTEXT_PUSH(val);
				res = ucstomb(buff, val);
				if((int) res <= 0) {
#ifdef USE_UTF8_IF_POSSIBLE
			    	if(!forSymbol) {
						use_wcs = TRUE;
			    	} else
#endif
				    {
						if(delim)
						    error(_("invalid \\u{xxxx} sequence (line %d)"), xxlineno);
						else
						    error(_("invalid \\uxxxx sequence (line %d)"), xxlineno);
				    }
				} else {
					for(i = 0; i <  res; i++) {
						STEXT_PUSH(buff[i]);
					}
				}
				continue;
#endif
			} else if(c == 'U') {
#ifndef SUPPORT_MBCS
				error(_("\\Uxxxxxxxx sequences not supported (line %d)"), xxlineno);
#else
				unsigned int val = 0; int i, ext; size_t res;
				char buff[MB_CUR_MAX+1]; /* could be variable, and hence not legal C90 */
				Rboolean delim = FALSE;
				if((c = xxgetc()) == '{') {
				    delim = TRUE;
				    CTEXT_PUSH(c);
				} else xxungetc(c);
				for(i = 0; i < 8; i++) {
				    c = xxgetc(); CTEXT_PUSH(c);
				    if(c >= '0' && c <= '9') ext = c - '0';
				    else if (c >= 'A' && c <= 'F') ext = c - 'A' + 10;
				    else if (c >= 'a' && c <= 'f') ext = c - 'a' + 10;
				    else {
						xxungetc(c);
						CTEXT_POP();
						if (i == 0) { /* was just \x */
						    if(GenerateCode && R_WarnEscapes) {
								have_warned++;
								warningcall(R_NilValue, _("\\U used without hex digits"));
						    }
						    val = 'U';
						}
						break;
				    }
				    val = 16*val + ext;
				}
				if(delim) {
				    if((c = xxgetc()) != '}') {
						error(_("invalid \\U{xxxxxxxx} sequence (line %d)"), xxlineno);
				    } else { 
						CTEXT_PUSH(c);
					}
				}
				res = ucstomb(buff, val);
				if((int)res <= 0) {
				    if(delim) {
						error(_("invalid \\U{xxxxxxxx} sequence (line %d)"), xxlineno);
					} else {
						error(_("invalid \\Uxxxxxxxx sequence (line %d)"), xxlineno);
					}
				}
				for(i = 0; i <  res; i++) {
					STEXT_PUSH(buff[i]);
				}
				WTEXT_PUSH(val);
				continue;
#endif
		    }
		    else {
				switch (c) {
					case 'a':
					    c = '\a';
					    break;
					case 'b':
					    c = '\b';
					    break;
					case 'f':
					    c = '\f';
					    break;
					case 'n':
					    c = '\n';
					    break;
					case 'r':
					    c = '\r';
					    break;
					case 't':
					    c = '\t';
					    break;
					case 'v':
					    c = '\v';
					    break;
					case '\\':
					    c = '\\';
					    break;
					case '"':
					case '\'':
					case ' ':
					case '\n':
					    break;
					default:
					    if(GenerateCode && R_WarnEscapes) {
							have_warned++;
							warningcall(R_NilValue, _("'\\%c' is an unrecognized escape in a character string"), c);
					    }
					    break;
				}
		    }
		}
#if defined(SUPPORT_MBCS)
		else if(mbcslocale) { 
			int i, clen;
			wchar_t wc = L'\0';
			/* We can't assume this is valid UTF-8 */
			clen = /* utf8locale ? utf8clen(c):*/ mbcs_get_next(c, &wc);
			WTEXT_PUSH(wc);
			for(i = 0; i < clen - 1; i++){
			    STEXT_PUSH(c);
			    c = xxgetc();
			    if (c == R_EOF) break;
			    CTEXT_PUSH(c);
			    if (c == '\n') {
				   xxungetc(c); CTEXT_POP();
				   c = '\\';
			    }
			}
			if (c == R_EOF) break;
			STEXT_PUSH(c);
			continue;
       }
#endif /* SUPPORT_MBCS */
		STEXT_PUSH(c);
#ifdef USE_UTF8_IF_POSSIBLE
		if ((unsigned int) c < 0x80) WTEXT_PUSH(c);
		else { /* have an 8-bit char in the current encoding */
		    wchar_t wc;
		    char s[2] = " ";
		    s[0] = c;
		    mbrtowc(&wc, s, 1, NULL);
		    WTEXT_PUSH(wc);
		}
#endif
    }
    STEXT_PUSH('\0');
    WTEXT_PUSH(0);
    if(forSymbol) {
		PROTECT(yylval = install(stext));
		if(stext != st0) free(stext);
		return SYMBOL;
    } else { 
#ifdef USE_UTF8_IF_POSSIBLE
		if(use_wcs) { 
		    if(wcnt < 1000){
				PROTECT(yylval = mkStringUTF8(wcs, wcnt)); /* include terminator */
		    } else {
				error(_("string at line %d containing Unicode escapes not in this locale\nis too long (max 1000 chars)"), xxlineno);
			}
		} else
#endif
	    PROTECT(yylval = mkString2(stext,  bp - stext - 1));
		if(stext != st0) free(stext);
		if(have_warned) {
		    *ct = '\0';
#ifdef ENABLE_NLS
	    	warningcall(R_NilValue,
				ngettext("unrecognized escape removed from \"%s\"",
					 "unrecognized escapes removed from \"%s\"",
					 have_warned),
				currtext);
#else
	    	warningcall(R_NilValue,
				"unrecognized escape(s) removed from \"%s\"", currtext);
#endif
		}
		return STR_CONST;
    }
}
/*}}}*/

/*{{{ isValidName */
/**
 * Checks validity of a symbol name
 * 
 * @return 1 if name is a valid name 0 otherwise 
 */
int isValidName(const char *name){
    const char *p = name;
    int i;

#ifdef SUPPORT_MBCS
    if(mbcslocale) {
		/* the only way to establish which chars are alpha etc is to
		   use the wchar variants */
		int n = strlen(name), used;
		wchar_t wc;
		used = Mbrtowc(&wc, p, n, NULL); p += used; n -= used;
		if(used == 0) return 0;
		if (wc != L'.' && !iswalpha(wc) ) return 0;
		if (wc == L'.') {
		    /* We don't care about other than ASCII digits */
		    if(isdigit(0xff & (int)*p)) return 0;
		    /* Mbrtowc(&wc, p, n, NULL); if(iswdigit(wc)) return 0; */
		}
		while((used = Mbrtowc(&wc, p, n, NULL))) {
		    if (!(iswalnum(wc) || wc == L'.' || wc == L'_')) break;
		    p += used; n -= used;
		}
		if (*p != '\0') return 0;
    } else
#endif
    {
		int c = 0xff & *p++;
		if (c != '.' && !isalpha(c) ) return 0;
		if (c == '.' && isdigit(0xff & (int)*p)) return 0;
		while ( c = 0xff & *p++, (isalnum(c) || c == '.' || c == '_') ) ;
		if (c != '\0') return 0;
    }

    if (strcmp(name, "...") == 0) return 1;

    for (i = 0; keywords[i].name != NULL; i++){
		if (strcmp(keywords[i].name, name) == 0) return 0;
	}
    return 1;
}
/*}}}*/

/*{{{ SymbolValue */
/**
 * Content of an operator, like %op% 
 * 
 * @param c
 * @return  
 */
static int SpecialValue(int c) {
    DECLARE_YYTEXT_BUFP(yyp);
    YYTEXT_PUSH(c, yyp);
    while ((c = xxgetc()) != R_EOF && c != '%') {
		if (c == '\n') {
		    xxungetc(c);
		    return ERROR;
		}
		YYTEXT_PUSH(c, yyp);
    }
    if (c == '%') {
		YYTEXT_PUSH(c, yyp);
	}
    YYTEXT_PUSH('\0', yyp);
    yylval = install(yytext);
    return SPECIAL;
}
/*}}}*/

/*{{{ SymbolValue */
static int SymbolValue(int c)
{
    int kw;
    DECLARE_YYTEXT_BUFP(yyp);
#if defined(SUPPORT_MBCS)
    if(mbcslocale) {
	wchar_t wc; int i, clen;
	   /* We can't assume this is valid UTF-8 */
	clen = /* utf8locale ? utf8clen(c) :*/ mbcs_get_next(c, &wc);
	while(1) {
	    /* at this point we have seen one char, so push its bytes
	       and get one more */
	    for(i = 0; i < clen; i++) {
		YYTEXT_PUSH(c, yyp);
		c = xxgetc();
	    }
	    if(c == R_EOF) break;
	    if(c == '.' || c == '_') {
		clen = 1;
		continue;
	    }
	    clen = mbcs_get_next(c, &wc);
	    if(!iswalnum(wc)) break;
	}
    } else
#endif
	do {
	    YYTEXT_PUSH(c, yyp);
	} while ((c = xxgetc()) != R_EOF &&
		 (isalnum(c) || c == '.' || c == '_'));
    xxungetc(c);
    YYTEXT_PUSH('\0', yyp);
    if ((kw = KeywordLookup(yytext))) {
	if ( kw == FUNCTION ) {
	    if (FunctionLevel >= MAXNEST)
		error(_("functions nested too deeply in source code at line %d"), xxlineno);
	    if ( FunctionLevel++ == 0 && GenerateCode) {
		strcpy((char *)FunctionSource, "function");
		SourcePtr = FunctionSource + 8;
	    }
	    FunctionStart[FunctionLevel] = SourcePtr - 8;
#if 0
	    printf("%d,%d\n", SourcePtr - FunctionSource, FunctionLevel);
#endif
	}
	return kw;
    }
    PROTECT(yylval = install(yytext));
    return SYMBOL;
}
/*}}} */

/*{{{ token */
/** 
 * Split the input stream into tokens.
 * This is the lowest of the parsing levels.
 * 
 * @return the token type once characters are consumed
 */
static int token(void) {
	
    int c;
#if defined(SUPPORT_MBCS)
    wchar_t wc;
#endif

    if (SavedToken) {
		c = SavedToken;
		yylval = SavedLval;
		SavedLval = R_NilValue;
		SavedToken = 0;
		yylloc.first_line = xxlinesave;
		yylloc.first_column = xxcolsave;
		yylloc.first_byte = xxbytesave;
		return c;
    }
	/* want to be able to go back one token */
    xxcharsave = xxcharcount; 

	/* eat any number of spaces */
	/* TODO: keep this instead in VERBOSE mode */
    c = SkipSpace();
	
	/* flush the comment */
	/* TODO: keep the comment in VERBOSE mode */
    if (c == '#') {
		c = SkipComment();
	}

    yylloc.first_line = xxlineno;
    yylloc.first_column = xxcolno;
    yylloc.first_byte = xxbyteno;

    if (c == R_EOF) {
		return END_OF_INPUT;
	}

    /* Either digits or symbols can start with a "." */
    /* so we need to decide which it is and jump to  */
    /* the correct spot. */
    if (c == '.' && typeofnext() >= 2) {
		goto symbol;
	}

    /* literal numbers */
    if (c == '.') {
		return NumericValue(c);
	}
	
    /* We don't care about other than ASCII digits */
    if (isdigit(c)){
		return NumericValue(c);
	}

    /* literal strings */
	if (c == '\"' || c == '\''){
		return StringValue(c, FALSE);
	}

    /* special functions */
    if (c == '%'){
		return SpecialValue(c);
	}

    /* functions, constants and variables */
    if (c == '`'){
		return StringValue(c, TRUE);
	}

	symbol:

		if (c == '.'){
			return SymbolValue(c);
		}
#if defined(SUPPORT_MBCS)
    	if(mbcslocale) {
			mbcs_get_next(c, &wc);
			if (iswalpha(wc)) {
				return SymbolValue(c);
			}
    	} else
#endif
		{ 
			if (isalpha(c)) {
				return SymbolValue(c);
			}
		}

    /* compound tokens */

    switch (c) {  
    	case '<':
			if (nextchar('=')) {
			    yylval = install("<=");
			    return LE;
			}
			if (nextchar('-')) {
			    yylval = install("<-");
			    return LEFT_ASSIGN;
			}
			if (nextchar('<')) {
			    if (nextchar('-')) {
					yylval = install("<<-");
					return LEFT_ASSIGN;
			    }
			    else
				return ERROR;
			}
			yylval = install("<");
			return LT;
    	case '-':
			if (nextchar('>')) {
			    if (nextchar('>')) {
					yylval = install("<<-");
					return RIGHT_ASSIGN;
			    }
			    else {
					yylval = install("<-");
					return RIGHT_ASSIGN;
			    }
			}
			yylval = install("-");
			return '-';
    	case '>':
			if (nextchar('=')) {
			    yylval = install(">=");
			    return GE;
			}
			yylval = install(">");
			return GT;
    	case '!':
			if (nextchar('=')) {
			    yylval = install("!=");
			    return NE;
			}
			yylval = install("!");
			return '!';
    	case '=':
			if (nextchar('=')) {
			    yylval = install("==");
			    return EQ;
			}
			yylval = install("=");
			return EQ_ASSIGN;
    	case ':':
			if (nextchar(':')) {
			    if (nextchar(':')) {
					yylval = install(":::");
					return NS_GET_INT;
			    } else {
					yylval = install("::");
					return NS_GET;
			    }
			}
			if (nextchar('=')) {
			    yylval = install(":=");
			    return LEFT_ASSIGN;
			}
			yylval = install(":");
			return ':';
    	case '&':
			if (nextchar('&')) {
			    yylval = install("&&");
			    return AND2;
			}
			yylval = install("&");
			return AND;
    	case '|':
			if (nextchar('|')) {
			    yylval = install("||");
			    return OR2;
			}
			yylval = install("|");
			return OR;
    	case LBRACE:
			yylval = install("{");
			return c;
    	case RBRACE:
			return c;
    	case '(':
			yylval = install("(");
			return c;
    	case ')':
			return c;
    	case '[':
			if (nextchar('[')) {
			    yylval = install("[[");
			    return LBB;
			}
			yylval = install("[");
			return c;
    	case ']':
			return c;
    	case '?':
			strcpy(yytext, "?");
			yylval = install(yytext);
			return c;
    	case '*':
			/* Replace ** by ^.  This has been here since 1998, but is
			   undocumented (at least in the obvious places).  It is in
			   the index of the Blue Book with a reference to p. 431, the
			   help for 'Deprecated'.  S-PLUS 6.2 still allowed this, so
			   presumably it was for compatibility with S. */
			if (nextchar('*'))
			    c='^';
			yytext[0] = c;
			yytext[1] = '\0';
			yylval = install(yytext);
			return c;
    	case '+':
    	case '/':
    	case '^':
    	case '~':
    	case '$':
    	case '@':
			yytext[0] = c;
			yytext[1] = '\0';
			yylval = install(yytext);
			return c;
    	default:
			return c;
    }
}
/*}}}*/

/*{{{ setlastloc */
/**
 * fills the yyloc structure
 */
static void setlastloc(void) {
    yylloc.last_line = xxlineno;
    yylloc.last_column = xxcolno;
    yylloc.last_byte = xxbyteno;
}
/*}}}*/ 

/*{{{ yylex */
/*----------------------------------------------------------------------------
 *
 *  The Lexical Analyzer:
 *
 *  Basic lexical analysis is performed by the following
 *  routines.  Input is read a line at a time, and, if the
 *  program is in batch mode, each input line is echoed to
 *  standard output after it is read.
 *
 *  The function yylex() scans the input, breaking it into
 *  tokens which are then passed to the parser.  The lexical
 *  analyser maintains a symbol table (in a very messy fashion).
 *
 *  The fact that if statements need to parse differently
 *  depending on whether the statement is being interpreted or
 *  part of the body of a function causes the need for ifpop
 *  and IfPush.  When an if statement is encountered an 'i' is
 *  pushed on a stack (provided there are parentheses active).
 *  At later points this 'i' needs to be popped off of the if
 *  stack.
 *
 */
  
/**
 * The lexical analyzer function. recognizes tokens from 
 * the input stream and returns them to the parser
 * 
 */
static int yylex(void){
	int tok;
	
	again:

		/* gets a token */
		tok = token();
		
    	/* Newlines must be handled in a context */
    	/* sensitive way.  The following block of */
    	/* deals directly with newlines in the */
    	/* body of "if" statements. */
    	if (tok == '\n') {
    	
			if (EatLines || *contextp == '[' || *contextp == '(')
			    goto again;
    		
			/* The essence of this is that in the body of */
			/* an "if", any newline must be checked to */
			/* see if it is followed by an "else". */
			/* such newlines are discarded. */
    		
			if (*contextp == 'i') {
    		
			    /* Find the next non-newline token */
    		
			    while(tok == '\n'){
					tok = token();
				}
    		
			    /* If we encounter "}", ")" or "]" then */
			    /* we know that all immediately preceding */
			    /* "if" bodies have been terminated. */
			    /* The corresponding "i" values are */
			    /* popped off the context stack. */
    		
			    if (tok == RBRACE || tok == ')' || tok == ']' ) {
					while (*contextp == 'i'){
					    ifpop();
					}
					*contextp-- = 0;
					setlastloc();
					return tok;
			    }
    		
			    /* When a "," is encountered, it terminates */
			    /* just the immediately preceding "if" body */
			    /* so we pop just a single "i" of the */
			    /* context stack. */
    		
			    if (tok == ',') {
					ifpop();
					setlastloc();
					return tok;
			    }
    		
			    /* Tricky! If we find an "else" we must */
			    /* ignore the preceding newline.  Any other */
			    /* token means that we must return the newline */
			    /* to terminate the "if" and "push back" that */
			    /* token so that we will obtain it on the next */
			    /* call to token.  In either case sensitivity */
			    /* is lost, so we pop the "i" from the context */
			    /* stack. */
    		
			    if(tok == ELSE) {
					EatLines = 1;
					ifpop();
					setlastloc();
					return ELSE;
			    } else {
					ifpop();
					SavedToken = tok;
					xxlinesave = yylloc.first_line;
					xxcolsave  = yylloc.first_column;
					xxbytesave = yylloc.first_byte;
					SavedLval = yylval;
					setlastloc();
					return '\n';
			    }
			} else {
			    setlastloc();
			    return '\n';
			}
    	}
    	
    	/* Additional context sensitivities */
    	
    	switch(tok) {
    	
			/* Any newlines immediately following the */
			/* the following tokens are discarded. The */
			/* expressions are clearly incomplete. */
    		
    		case '+':
    		case '-':
    		case '*':
    		case '/':
    		case '^':
    		case LT:
    		case LE:
    		case GE:
    		case GT:
    		case EQ:
    		case NE:
    		case OR:
    		case AND:
    		case OR2:
    		case AND2:
    		case SPECIAL:
    		case FUNCTION:
    		case WHILE:
    		case REPEAT:
    		case FOR:
    		case IN:
    		case '?':
    		case '!':
    		case '=':
    		case ':':
    		case '~':
    		case '$':
    		case '@':
    		case LEFT_ASSIGN:
    		case RIGHT_ASSIGN:
    		case EQ_ASSIGN:
				EatLines = 1;
				break;
    		
			/* Push any "if" statements found and */
			/* discard any immediately following newlines. */
    		
    		case IF:
				IfPush();
				EatLines = 1;
				break;
    		
			/* Terminate any immediately preceding "if" */
			/* statements and discard any immediately */
			/* following newlines. */
    		
    		case ELSE:
				ifpop();
				EatLines = 1;
				break;
    		
			/* These tokens terminate any immediately */
			/* preceding "if" statements. */
    		
    		case ';':
    		case ',':
				ifpop();
			break;
    		
			/* Any newlines following these tokens can */
			/* indicate the end of an expression. */
    		
    		case SYMBOL:
    		case STR_CONST:
    		case NUM_CONST:
    		case NULL_CONST:
    		case NEXT:
    		case BREAK:
				EatLines = 0;
				break;
    		
			/* Handle brackets, braces and parentheses */
    		
    		case LBB:
				if(contextp - contextstack >= CONTEXTSTACK_SIZE - 1)
				    error(_("contextstack overflow at line %d"), xxlineno);
				*++contextp = '[';
				*++contextp = '[';
				break;
    		
    		case '[':
				if(contextp - contextstack >= CONTEXTSTACK_SIZE)
				    error(_("contextstack overflow at line %d"), xxlineno);
				*++contextp = tok;
				break;
    		
    		case LBRACE:
				if(contextp - contextstack >= CONTEXTSTACK_SIZE)
				    error(_("contextstack overflow at line %d"), xxlineno);
				*++contextp = tok;
				EatLines = 1;
				break;
    		
    		case '(':
				if(contextp - contextstack >= CONTEXTSTACK_SIZE)
				    error(_("contextstack overflow at line %d"), xxlineno);
				*++contextp = tok;
				break;
    		
    		case ']':
				while (*contextp == 'i')
				    ifpop();
				*contextp-- = 0;
				EatLines = 0;
				break;
    		
    		case RBRACE:
				while (*contextp == 'i')
				    ifpop();
				*contextp-- = 0;
				break;
    		
    		case ')':
				while (*contextp == 'i')
				    ifpop();
				*contextp-- = 0;
				EatLines = 0;
				break;
    	
    	}
    	setlastloc();
    	return tok;
}
/*}}}*/

/*}}}*/


/*{{{ Parsing exntry points */

/*{{{ file_getc */
static int file_getc(void){
    return R_fgetc(fp_parse);
}
/*}}}*/

/*{{{ ParseContextInit */
static void ParseContextInit(void) {
    R_ParseContextLast = 0;
    R_ParseContext[0] = '\0';
}
/*}}}*/
           
/*{{{ ParseInit */
static void ParseInit(void) {
    contextp = contextstack;
    *contextp = ' ';
    SavedToken = 0;
    SavedLval = R_NilValue;
    EatLines = 0;
    EndOfFile = 0;
    FunctionLevel=0;
    SourcePtr = FunctionSource;
    xxcharcount = 0;
    KeepSource = *LOGICAL(GetOption(install("keep.source"), R_BaseEnv));
    npush = 0;
}
/*}}}*/

/*{{{ R_Parse1 */
static SEXP R_Parse1(ParseStatus *status) {
	
	int res = yyparse() ;
	Rprintf( "result from yyparse: %d \n", res ) ; 
	
	switch(res) {
    	case 0:                     /* End of file */
			*status = PARSE_EOF;
			if (EndOfFile == 2) {
				*status = PARSE_INCOMPLETE;
			}
			break;
    	case 1:                     /* Syntax error / incomplete */
			*status = PARSE_ERROR;
			if (EndOfFile) {
				*status = PARSE_INCOMPLETE;
			}
			break;
    	case 2:                     /* Empty Line */
			*status = PARSE_NULL;
			break;
    	case 3:                     /* Valid expr '\n' terminated */
    	case 4:                     /* Valid expr ';' terminated */
			*status = PARSE_OK;
			break;
    }
    return R_CurrentExpr;
}
/*}}}*/

/*{{{ R_Parse */
static SEXP R_Parse(int n, ParseStatus *status, SEXP srcfile){
	
    volatile int savestack;
    int i;
    SEXP t, rval;

    ParseContextInit();
    savestack = R_PPStackTop;
    PROTECT(t = NewList());

    xxlineno = 1;
    xxcolno = 0;
    xxbyteno = 0;
    if (!isNull(srcfile)) {
		SrcFile = srcfile;
		PROTECT(SrcRefs = NewList() );
    } else {
		SrcFile = NULL;
	}

    for(i = 0; ; ) {
		if(n >= 0 && i >= n) break;
		ParseInit();
		rval = R_Parse1(status);
		Rprintf( "step %d: %d \n", i, *status ) ;
		
		switch(*status) {
			case PARSE_NULL:
			    break;
			case PARSE_OK:
			    t = GrowList(t, rval);
			    i++;
			    break;
			case PARSE_INCOMPLETE:
			case PARSE_ERROR:
			    R_PPStackTop = savestack;
			    SrcFile = NULL;
			    return R_NilValue;
			    break;
			case PARSE_EOF:
			    goto finish;
			    break;
		}
    }

finish:

    t = CDR(t);
    rval = allocVector(EXPRSXP, length(t));
    for (n = 0 ; n < LENGTH(rval) ; n++, t = CDR(t)){
		SET_VECTOR_ELT(rval, n, CAR(t));
	}
    if (SrcFile) {
		rval = attachSrcrefs(rval, SrcFile);
		SrcFile = NULL;
    }
    R_PPStackTop = savestack;
    *status = PARSE_OK;
	UNPROTECT(2) ;
	
    return rval;
}
/*}}}*/

/*{{{ R_ParseFile */
attribute_hidden 
SEXP R_ParseFile(FILE *fp, int n, ParseStatus *status, SEXP srcfile) {
    GenerateCode = 1;
    fp_parse = fp;
    ptr_getc = file_getc;
    return R_Parse(n, status, srcfile);
}
/*}}}*/

/*}}}*/
