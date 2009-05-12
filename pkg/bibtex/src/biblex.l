%{

#include "bibtex.h"
#include "bibparse.h" 

#define YYSTYPE SEXP 
#include <stdio.h>
#include <string.h>
#include <ctype.h>
#include <stdlib.h>

typedef int token_t ;

static void		compact_space();
static void		eof_error();
static int		next_char();
static token_t		out_braced_literal();
static token_t		out_braced_string();
static token_t		out_lbrace();
static token_t		out_lparen();
static token_t		out_protected_string(token_t t);
static token_t		out_rbrace();
static token_t		out_rparen();
static token_t		out_string();
static token_t		out_token(token_t t_);
static void		overflow();

static int		brace_level = 0;
int			do_lex_output = 0;
static token_t		last_object = TOKEN_UNKNOWN;
static token_t		last_token = TOKEN_UNKNOWN;
long			line_number = 1L; /* global: used in lexmain() */
static int		paren_level = 0;

#define BYTE_VAL(c)	((unsigned int)((c) & 0xff))
#define EOFILE		0		/* end-of-file from lex input() */
#define ISPRINT(c)	isprint(BYTE_VAL(c)) /* ensure arg in 0..255 */
#define ISDIGIT(c)	isdigit(BYTE_VAL(c))
#define ISSPACE(c)	isspace(BYTE_VAL(c))
#define RETURN(n)	return (n)

#undef YYLMAX

#if defined(HAVE_IBMPC)
#define YYLMAX	32760
#else
#define YYLMAX	BIBYYLMAX
#endif

%}
			/* increase transition and output table sizes */
%a		3000
%o		6000
				/* abbrev, entry, key, field name syntax */
N		[A-Za-z][-A-Za-z0-9:.+/']*
					/* BibTeX entry opening delimiter */
O		[({]
					/* one white space character */
					/* \013 == \v, but lex doesn't */
					/* recognize \v */
W		[ \f\r\t\013]
					/* optional `horizontal' space */
S		{W}*

%%
[@]				RETURN (out_token(TOKEN_AT));

[Cc][Oo][Mm][Mm][Ee][Nn][Tt]	{RETURN ((last_token == TOKEN_AT) ?
					out_token(TOKEN_COMMENT) :
					out_token(TOKEN_ABBREV)); }

[Ii][Nn][Cc][Ll][Uu][Dd][Ee]	{RETURN ((last_token == TOKEN_AT) ?
					out_token(TOKEN_INCLUDE) :
					out_token(TOKEN_ABBREV)); }

[Pp][Rr][Ee][Aa][Mm][Bb][Ll][Ee] { RETURN ((last_token == TOKEN_AT) ?
					out_token(TOKEN_PREAMBLE) :
					out_token(TOKEN_ABBREV)); }

[Ss][Tt][Rr][Ii][Nn][Gg]	{ RETURN ((last_token == TOKEN_AT) ?
					out_token(TOKEN_STRING) :
					out_token(TOKEN_ABBREV)); }

{N}				{
				    if (last_object == TOKEN_STRING)
					RETURN(out_token(TOKEN_ABBREV));
				    switch (last_token)
				    {
				    case TOKEN_COMMA:
					RETURN(out_token(TOKEN_FIELD));
				    case TOKEN_LBRACE:
					RETURN(out_token(TOKEN_KEY));
				    case TOKEN_AT:
					RETURN(out_token(TOKEN_ENTRY));
				    default:
					RETURN(out_token(TOKEN_ABBREV));
				    }
				}

[0-9]+				RETURN (out_token(TOKEN_VALUE));

[%].*[\n]{S}			RETURN (out_token(TOKEN_INLINE));

[#]				RETURN (out_token(TOKEN_SHARP));

["]				RETURN (out_string());

[{]				RETURN (out_lbrace());

[}]				RETURN (out_rbrace());

[(]				RETURN (out_lparen());

[)]				RETURN (out_rparen());

[=]				RETURN (out_token(TOKEN_EQUALS));

[,]				RETURN (out_token(TOKEN_COMMA));

[\n]				RETURN (out_token(TOKEN_NEWLINE));

{W}+				RETURN (out_token(TOKEN_SPACE));

.				RETURN (out_token(TOKEN_LITERAL));

%%

/*{{{ compact_space */
/**
 * compact runs of space to single blank 
 */
static void compact_space(){
    char *p;
    char *q;

    for (p = q = (char*)&yytext[0]; *p ; ) {
		*q++ = ISSPACE(*p) ? ' ' : *p;
		if (ISSPACE(*p)){
		    while (ISSPACE(*p))
			++p;
		} else{
			++p;
    	}
	}
    *q = '\0';
}
/*}}}*/


static void eof_error(){
    Rprintf( "End-of-file in value string\n" );
}


static int next_char() {
    int c;

    c = input();
    if ( c == R_EOF ){	
		eof_error();
    } else if (c == '\n'){
		line_number++;
	}
    return (c);
}


static token_t out_braced_literal(){
    int c;
    int n;
    int plevel = paren_level;

    for (n = 1; brace_level > 0; ) {
		c = next_char();
		if (c == EOF){
		    break;
		}
		if (n > (YYLMAX - 2)){
		    overflow();
		}
		yytext[n++] = c;
		switch (c){
			case '(':
			    plevel++;
			    break;
			case ')':
			    plevel--;
			    break;
			case '{':
			    brace_level++;
			    break;
			case '}':
			    brace_level--;
			    break;
			default:
			    break;
		}
		if ((paren_level > 0) && (plevel == 0)){
		    break;
		}
    }
    yytext[0] = '{';
    yytext[n-1] = '}';
    yytext[n] = '\0';
    return (out_token(TOKEN_LITERAL));
}

/* convert braced to quoted string */
static token_t out_braced_string() {
    int blevel;
    int c;
    int n;

    for (blevel = 1, n = 1; (blevel > 0); ){
		c = next_char();
		if (c == EOF){
		    break;
		}
		if (n > (YYLMAX - 5)){
		    overflow();
		}
		yytext[n++] = c;
		switch (c){
			case '{':
			    blevel++;
			    break;
    		
			case '}':
			    blevel--;
			    break;
    		
			case '"':
			    if (blevel == 1){
					if (yytext[n-2] == '\\') {
					    c = next_char();
					    if (c == EOF){
							break;
						}
					    yytext[n-2] = '{';
					    yytext[n-1] = '\\';
					    yytext[n++] = '"';
					    yytext[n++] = c;
					    yytext[n++] = '}';
					} else {
					    yytext[n-1] = '{';
					    yytext[n++] = '"';
					    yytext[n++] = '}';
					}
			    }
			    break;
    		
			default:
			    break;
		}
    }
    yytext[0] = '"';
    yytext[n-1] = '"';
    yytext[n] = '\0';
    return (out_token(TOKEN_VALUE));
}


static token_t out_lbrace(){
    if (brace_level == 0){
		brace_level++;
		switch (last_object) {
			case TOKEN_COMMENT:
			case TOKEN_INCLUDE:
			    return (out_braced_literal());
			default:
			    return (out_token(TOKEN_LBRACE));
		}
    }
    else {
		return (out_braced_string());
	}
}


static token_t out_lparen(){
    switch (last_token) {
    	case TOKEN_ENTRY:
    	case TOKEN_PREAMBLE:
    	case TOKEN_STRING:
			yytext[0] = '{';
			paren_level++;
			brace_level++;
			return (out_token(TOKEN_LBRACE));
    	
    	case TOKEN_COMMENT:
    	case TOKEN_INCLUDE:
			yytext[0] = '{';
			paren_level++;
			brace_level++;
			return (out_braced_literal());
    	
    	default:
			return (out_token(TOKEN_LITERAL));
    }
}

static token_t out_protected_string(token_t t){
    char octal[4 + 1];
    const char *token = (const char*)&yytext[0];

    if (*token == (char)'\0')	/* ignore empty tokens */
	return (TOKEN_VALUE);
    output('"');
	
	/* supply missing quote delimiters */
    if ((yytext[0] != '"') && (t == TOKEN_VALUE)){
		output('\\');
		output('\"');
    }
    for (; *token; ++token){ 
		switch (*token) {
			case '"':
			case '\\':
			    output('\\');
			    output(*token);
			    break;
			case '\b':
			    output('\\');
			    output('b');
			    break;
			case '\f':
			    output('\\');
			    output('f');
			    break;
			case '\n':
			    output('\\');
			    output('n');
			    break;
			case '\r':
			    output('\\');
			    output('r');
			    break;
			case '\t':
			    output('\\');
			    output('t');
			    break;
			case '\v':
			    output('\\');
			    output('v');
			    break;
			default:
			    if (ISPRINT(*token)){
					output(*token);
				} else {
					(void)sprintf(octal,"\\%03o",BYTE_VAL(*token));
					output(octal[0]);
					output(octal[1]);
					output(octal[2]);
					output(octal[3]);
			    }
			    break;
		}
    }
	/* supply missing quote delimiters */
    if ((yytext[0] != '"') && (t == TOKEN_VALUE)){
		output('\\');
		output('\"');
    }
    output('"');
    output('\n');
    return (TOKEN_VALUE);
}


static token_t out_rbrace() {
    if (brace_level == 1) {
		brace_level--;
		return (out_token(TOKEN_RBRACE));
    }
    else{ 
		return (out_token(TOKEN_LITERAL));
	}
}


static token_t out_rparen(){
    paren_level--;
    if (paren_level  == 0){
		yytext[0] = '}';
		brace_level--;
		return (out_token(TOKEN_RBRACE));
    } else {
		return (out_token(TOKEN_LITERAL));
	}
}


static token_t out_string(){
    int blevel;
    int c;
    int n;

    for (blevel = 0, n = 1; ; ) {
		c = next_char();
		if (c == EOF){
		    break;
		}
		if (n > (YYLMAX - 2)){
		    overflow();
		}
		yytext[n++] = c;
		switch (c){
			case '{':
			    blevel++;
			    break;
			case '}':
			    blevel--;
			    break;
			case '"':
			    if (blevel == 0){
					goto LOOP_EXIT;
				}
			default:
			    break;
		}
    }
 LOOP_EXIT:
    yytext[n++] = '\0';
    return (out_token(TOKEN_VALUE));
}

/* ALL token output is directed through this function */
static token_t out_token(token_t t){
    int n;
	
	if (do_lex_output){
		Rprintf("%d\t", (int)t);
	}
    switch (t) {
    	case TOKEN_AT:
			last_object = TOKEN_UNKNOWN;
			if (do_lex_output)
			    Rprintf("\"%s\"\n", yytext);
			break;
    	
    	case TOKEN_VALUE:
			if (do_lex_output){
				/* supply surrounding quotes */
			    	if (ISDIGIT(yytext[0])) {
					n = strlen((const char*)&yytext[0]);
					if ((n + 3) > YYLMAX){
					    overflow();
					}
					yytext[n+2] = '\0';
					yytext[n+1] = '"';
					for (; n > 0; --n){
					    yytext[n] = yytext[n-1];
					}
			    }
			    else
				compact_space();
			    out_protected_string(t);
			}
			break;
    	
    	case TOKEN_COMMENT:
    	case TOKEN_INCLUDE:
			if (do_lex_output){
			    out_protected_string(t);
			}
			last_object = t;
			break;
    	
    	case TOKEN_ENTRY:
    	case TOKEN_PREAMBLE:
    	case TOKEN_STRING:
			if (do_lex_output){
			    (void)printf("\"%s\"\n", yytext);
			}
			last_object = t;
			break;
    	
    	case TOKEN_FIELD:
    	case TOKEN_KEY:
			if (do_lex_output){
			    (void)printf("\"%s\"\n", yytext);
			}
			break;
    	
    	case TOKEN_INLINE:
    	case TOKEN_NEWLINE:
			line_number++;
			if (do_lex_output) {
			    out_protected_string(t);
			    /* (void)printf("# line %ld \"%s\"\n", line_number, the_filename); */
			}
			break;
    	
    	case TOKEN_LITERAL:
    	default:
			if (do_lex_output){
			    out_protected_string(t);
			}
			break;
    }
    if (!((t == TOKEN_INLINE) ||
	  (t == TOKEN_SPACE) ||
	  (t == TOKEN_NEWLINE)))
	last_token = t;		/* remember last non-space token type */
    
	const char * token = (const char*)&yytext[0] ; 
	setToken( token, strlen(token) );
	
	return (t);
}

static void overflow(){
    REprintf("String too long for %ld-character buffer\n",YYLMAX);
}

int yywrap() {
    return 1;
}

/* :tabSize=4:indentSize=4:noTabs=false:folding=explicit:collapseFolds=1: */
