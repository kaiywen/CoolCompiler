/*
 *  The scanner definition for COOL.
 */

/*
 *  Stuff enclosed in %{ %} in the first section is copied verbatim to the
 *  output, so headers and global definitions are placed here to be visible
 * to the code in the file.  Don't remove anything that was here initially
 */
%{
#include <cool-parse.h>
#include <stringtab.h>
#include <utilities.h>

/* The compiler assumes these identifiers. */
#define yylval cool_yylval
#define yylex  cool_yylex

/* Max size of string constants */
#define MAX_STR_CONST 1025
#define YY_NO_UNPUT   /* keep g++ happy */

extern FILE *fin; /* we read from this file */

/* define YY_INPUT so we read from the FILE fin:
 * This change makes it possible to use this scanner in
 * the Cool compiler.
 */
#undef YY_INPUT
#define YY_INPUT(buf,result,max_size) \
	if ( (result = fread( (char*)buf, sizeof(char), max_size, fin)) < 0) \
		YY_FATAL_ERROR( "read() in flex scanner failed");

char string_buf[MAX_STR_CONST]; /* to assemble string constants */
char *string_buf_ptr;

extern int curr_lineno;
extern int verbose_flag;

extern YYSTYPE cool_yylval;

/*
 *  Add Your own definitions here
 */

int comment_depth = 0;
int str_length = 0;

void add_to_str(char* text);
bool check_str_length();
void reset_str_buf();

%}

/*
 * Define names for regular expressions here.
 */

DARROW          =>
ASSIGN          <-
LE              <=
DIGIT           [0-9]
LC_ALPHA        [a-z]
UC_ALPHA        [A-Z]
ALPHANUMERIC    [_a-zA-Z0-9]

/*
 * Define states for transitions here
 */

%x COMMENT
%x STRING
%x STRING_RESUME

%%

 /*
  *  Nested comments
  */

<INITIAL>"*)" {
    yylval.error_msg = "Unmatched *)";
    return (ERROR);
}

<INITIAL,COMMENT>"(*" {
    BEGIN(COMMENT);
    comment_depth++;
}

<COMMENT>"*)" {
    comment_depth--;
    if(comment_depth == 0) {
        BEGIN(INITIAL);
    }
}

<COMMENT><<EOF>> {
    BEGIN(INITIAL);
    yylval.error_msg = "EOF in comment";
    return (ERROR);
}

<COMMENT>"\n" {
    curr_lineno++;
}

<COMMENT>. { 
  /* Just skip, do nothing */ 
}


 /*
  * Single-line comment
  */

"--".*\n |
"--".* {
    curr_lineno++;
}


 /*
  *  The multiple-character operators.
  */

{DARROW}		{ return (DARROW); }
{ASSIGN}    { return (ASSIGN); }
{LE}        { return (LE); }
"="         { return '='; }
"<"         { return '<'; }
"+"         { return '+'; }
"-"         { return '-'; }
"*"         { return '*'; }
"/"         { return '/'; }
"{"         { return '{'; }
"}"         { return '}'; }
"("         { return '('; }
")"         { return ')'; }
"@"         { return '@'; }
"~"         { return '~'; }
"."         { return '.'; }
";"         { return ';'; }
":"         { return ':'; }
","         { return ','; }


 /*
  * Keywords are case-insensitive except for the values true and false,
  * which must begin with a lower-case letter.
  */

 /*
  * Patterns starting with "?i" are case-insensitive
  */
(?i:class)      { return (CLASS); }
(?i:else)       { return (ELSE); } 
(?i:fi)         { return (FI); }
(?i:if)         { return (IF); }
(?i:in)         { return (IN); }
(?i:inherits)   { return (INHERITS); }
(?i:isvoid)     { return (ISVOID); }
(?i:let)        { return (LET); }
(?i:loop)       { return (LOOP); }
(?i:pool)       { return (POOL); }
(?i:then)       { return (THEN); }
(?i:while)      { return (WHILE); }
(?i:case)       { return (CASE); }
(?i:esac)       { return (ESAC); }
(?i:new)        { return (NEW); }
(?i:of)         { return (OF); }
(?i:not)        { return (NOT); }  

 /*
  * Keywords "false" and "true" should be started with lower-case chars 
  */

"f"(?i:alse)  { 
    yylval.boolean = false;
    return (BOOL_CONST);
}

"t"(?i:rue)   { 
    yylval.boolean = true;
    return (BOOL_CONST);
}

 /*
  * Types, IDs and integers
  * Note that table.add_string(yytext) returns a pointer pointing to the inserted entry
  */

{UC_ALPHA}{ALPHANUMERIC}* {
    yylval.symbol = idtable.add_string(yytext);
    return (TYPEID);
}

{LC_ALPHA}{ALPHANUMERIC}* {
    yylval.symbol = idtable.add_string(yytext);
    return (OBJECTID);
}

{DIGIT}+ {
    yylval.symbol = inttable.add_string(yytext);
    return (INT_CONST);
}

 /*
  *  String constants (C syntax)
  *  Escape sequence \c is accepted for all characters c. Except for 
  *  \n \t \b \f, the result is c.
  *
  */

<INITIAL>"\"" {
    BEGIN(STRING);
    reset_str_buf();
}

 /*
  * Note that "\0" cannot be escaped in cool programing
  */
<STRING>(\0|\\\0) {
    BEGIN(STRING_RESUME);
    yylval.error_msg = "String contains null character";
    return (ERROR);
}

<STRING>"\n" {
    BEGIN(INITIAL);
    curr_lineno++;
    yylval.error_msg = "Unterminated string constant";
    return (ERROR);
}

<STRING><<EOF>> {
    BEGIN(INITIAL);
    yylval.error_msg = "EOF in string constant";
    return (ERROR);
}

<STRING>"\\n" {
    add_to_str("\n");
    if (check_str_length()) return (ERROR);
}

<STRING>"\\t" {
    add_to_str("\t");
    if (check_str_length()) return (ERROR);
}

<STRING>"\\b" {
    add_to_str("\b");
    if (check_str_length()) return (ERROR);
}

<STRING>"\\f" {
    add_to_str("\f");
    if (check_str_length()) return (ERROR);
}

<STRING>(\\.|\\\n) { 
    add_to_str(&strdup(yytext)[1]);
    if (check_str_length()) return (ERROR);
}

<STRING>"\"" {
    BEGIN(INITIAL);
    yylval.symbol = stringtable.add_string(string_buf);
    return (STR_CONST);

}

<STRING>. {
    add_to_str(yytext);
    if (check_str_length()) return (ERROR);
}

<STRING_RESUME>.*("\""|\n) {
    BEGIN(INITIAL);
}

\n   { curr_lineno++; }

[\r\t\v\f ] {    }

.    {
          yylval.error_msg = yytext;
          return(ERROR);
}


%%

void add_to_str(char* text) {
    strcat(string_buf, text);
    str_length++;
}

bool check_str_length() {
    if (str_length >= MAX_STR_CONST) {
        BEGIN(STRING_RESUME);
        yylval.error_msg = "String constant too long";
        return true;
    } else {
      return false;
    }
}

void reset_str_buf() {
    string_buf[0] = '\0';
    str_length = 0;
}
