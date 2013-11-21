/* -*- mode: c -*- */
/*
 * Parser grammar for beancount 2.0 input syntax.
 *
 * This assumes it feeds off the corresponding lexer in this pacakge. This is
 * meant to be used with the stock "go yacc" command.
 */

/*--------------------------------------------------------------------------------*/
/* Prologue */
%{

#include <stdio.h>
#include <assert.h>
#include "parser.h"
#include "lexer.h"

/* First line of reported file/line string. This is used as #line. */
int yy_firstline;

#define FILE_LINE_ARGS  yy_filename, ((yyloc).first_line + yy_firstline)

/* Error-handling function. */
void yyerror(char const* message)
{
    /* Register a syntax error with the builder. */
    BUILD("error", "ssi", message, yy_filename, yylineno + yy_firstline);
}

/* Get a printable version of a token name. */
const char* getTokenName(int token);


/* #define DECREF1(x)  Py_DECREF(x); */
#define DECREF1(x1)
#define DECREF2(x1, x2)
#define DECREF3(x1, x2, x3)
#define DECREF4(x1, x2, x3, x4)
#define DECREF5(x1, x2, x3, x4, x5)
#define DECREF6(x1, x2, x3, x4, x5, x6)

%}


/*--------------------------------------------------------------------------------*/
/* Bison Declarations */


/* Options. */
%defines
%error-verbose
%debug
%pure-parser
%locations
/* %glr-parser */

/* FIXME: Pass this explicitly eventually. */
/* %parse-param { PyObject* builder} */


/* Collection of value types. */
%union {
    char character;
    const char* string;
    PyObject* pyobj;
}

/* Types for terminal symbols */
%token <string> ERROR      /* error occurred; value is text of error */
%token <string> INDENT     /* Initial indent IF at the beginning of a line */
%token <string> EOL        /* End-of-line */
%token <string> COMMENT    /* A comment */
%token <string> SKIPPED    /* A line skipped because not a directive nor a comment */
%token <string> PIPE       /* | */
%token <string> ATAT       /* @@ */
%token <string> AT         /* @ */
%token <string> LCURL      /* { */
%token <string> RCURL      /* } */
%token <string> EQUAL      /* = */
%token <string> COMMA      /* , */
%token <string> SLASH      /* / */
%token <character> FLAG    /* Valid characters for flags */
%token TXN                 /* 'txn' keyword */
%token CHECK               /* 'check' keyword */
%token OPEN                /* 'open' keyword */
%token CLOSE               /* 'close' keyword */
%token PAD                 /* 'pad' keyword */
%token EVENT               /* 'event' keyword */
%token PRICE               /* 'price' keyword */
%token NOTE                /* 'note' keyword */
%token DOCUMENT            /* 'document' keyword */
%token PUSHTAG             /* 'pushtag' keyword */
%token POPTAG              /* 'poptag' keyword */
%token OPTION              /* 'option' keyword */
%token <pyobj> DATE        /* A date object */
%token <pyobj> ACCOUNT     /* The name of an account */
%token <pyobj> CURRENCY    /* A currency specification */
%token <pyobj> STRING      /* A quoted string, with any characters inside */
%token <pyobj> NUMBER      /* A floating-point number */
%token <pyobj> TAG         /* A tag that can be associated with a transaction */
%token <pyobj> LINK        /* A link that can be associated with a transaction */

/* Types for non-terminal symbols. */
%type <character> txn
%type <character> optflag
%type <pyobj> transaction
%type <pyobj> posting
%type <pyobj> posting_list
%type <pyobj> currency_list
%type <pyobj> open
%type <pyobj> close
%type <pyobj> check
%type <pyobj> pad
%type <pyobj> amount
%type <pyobj> position
%type <pyobj> lot_cost_date
%type <pyobj> price
%type <pyobj> event
%type <pyobj> note
%type <pyobj> document
%type <pyobj> entry
%type <pyobj> declarations
%type <pyobj> tags_list
%type <pyobj> links_list
%type <pyobj> filename


/* Start symbol. */
%start file

/* We have four expected shift/reduce conflicts at 'eol'. */
%expect 4


/*--------------------------------------------------------------------------------*/
/* Grammar Rules */
%%

empty :

/* A transaction declaration can be either 'txn' or one of the special character flags. */
txn : TXN
    {
        $$ = '*';
    }
    | FLAG
    {
        $$ = $1;
    }

eol : EOL
    | COMMENT EOL

/* FIXME: I want to add INDENT EOF and COMMENT EOF here.*/
empty_line : EOL
           | COMMENT EOL
           | INDENT EOL
           | INDENT
           | COMMENT

tags_list : empty
          {
              Py_INCREF(Py_None);
              $$ = Py_None;
          }
          | tags_list TAG
          {
              $$ = BUILD("handle_list", "OO", $1, $2);
              DECREF2($1, $2);
          }

links_list : empty
          {
              Py_INCREF(Py_None);
              $$ = Py_None;
          }
          | links_list LINK
          {
              $$ = BUILD("handle_list", "OO", $1, $2);
              DECREF2($1, $2);
          }

transaction : DATE txn STRING tags_list links_list eol posting_list
            {
                $$ = BUILD("transaction", "siObOOOOO", FILE_LINE_ARGS, $1, $2, Py_None, $3, $4, $5, $7);
                DECREF5($1, $3, $4, $5, $7);
            }
            | DATE txn STRING PIPE STRING tags_list links_list eol posting_list
            {
                $$ = BUILD("transaction", "siObOOOOO", FILE_LINE_ARGS, $1, $2, $3, $5, $6, $7, $9);
                DECREF6($1, $3, $5, $6, $7, $9);
            }

optflag : empty
        {
            $$ = '\0';
        }
        | FLAG

posting : INDENT optflag ACCOUNT position eol
        {
            $$ = BUILD("posting", "OOOOb", $3, $4, Py_None, Py_False, $2);
            DECREF2($3, $4);
        }
        | INDENT optflag ACCOUNT position AT amount eol
        {
            $$ = BUILD("posting", "OOOOb", $3, $4, $6, Py_False, $2);
            DECREF3($3, $4, $6);
        }
        | INDENT optflag ACCOUNT position ATAT amount eol
        {
            $$ = BUILD("posting", "OOOOb", $3, $4, $6, Py_True, $2);
            DECREF3($3, $4, $6);
        }
        | INDENT optflag ACCOUNT eol
        {
            $$ = BUILD("posting", "OOOOb", $3, Py_None, Py_None, Py_False, $2);
            DECREF1($3);
        }

posting_list : empty
             {
                 Py_INCREF(Py_None);
                 $$ = Py_None;
             }
             | posting_list posting
             {
                 $$ = BUILD("handle_list", "OO", $1, $2);
                 DECREF2($1, $2);
             }

currency_list : empty
              {
                  Py_INCREF(Py_None);
                  $$ = Py_None;
              }
              | CURRENCY
              {
                  $$ = BUILD("handle_list", "OO", Py_None, $1);
                  DECREF1($1);
              }
              | currency_list COMMA CURRENCY
              {
                  $$ = BUILD("handle_list", "OO", $1, $3);
                  DECREF2($1, $3);
              }

pushtag : PUSHTAG TAG eol
         {
             BUILD("pushtag", "O", $2);
             DECREF1($2);
         }

poptag : POPTAG TAG eol
       {
           BUILD("poptag", "O", $2);
           DECREF1($2);
       }

open : DATE OPEN ACCOUNT currency_list eol
     {
         $$ = BUILD("open", "siOOO", FILE_LINE_ARGS, $1, $3, $4);
         DECREF3($1, $3, $4);
     }

close : DATE CLOSE ACCOUNT eol
      {
          $$ = BUILD("close", "siOO", FILE_LINE_ARGS, $1, $3);
          DECREF2($1, $3);
      }

pad : DATE PAD ACCOUNT ACCOUNT eol
    {
        $$ = BUILD("pad", "siOOO", FILE_LINE_ARGS, $1, $3, $4);
        DECREF3($1, $3, $4);
    }

check : DATE CHECK ACCOUNT amount eol
      {
          $$ = BUILD("check", "siOOO", FILE_LINE_ARGS, $1, $3, $4);
          DECREF3($1, $3, $4);
      }

amount : NUMBER CURRENCY
       {
         PyObject* o = BUILD("amount", "OO", $1, $2);
         $$ = o;
         DECREF2($1, $2);
       }

position : amount
           {
               $$ = BUILD("position", "OO", $1, Py_None);
               DECREF1($1);
           }
           | amount lot_cost_date
           {
               $$ = BUILD("position", "OO", $1, $2);
               DECREF2($1, $2);
           }

lot_cost_date : LCURL amount RCURL
         {
             $$ = BUILD("lot_cost_date", "OO", $2, Py_None);
             DECREF1($2);
         }
         | LCURL amount SLASH DATE RCURL
         {
             $$ = BUILD("lot_cost_date", "OO", $2, $4);
             DECREF2($2, $4);
         }


price : DATE PRICE CURRENCY amount eol
      {
          $$ = BUILD("price", "siOOO", FILE_LINE_ARGS, $1, $3, $4);
          DECREF3($1, $3, $4);
      }

event : DATE EVENT STRING STRING eol
      {
          $$ = BUILD("event", "siOOO", FILE_LINE_ARGS, $1, $3, $4);
          DECREF3($1, $3, $4);
      }

note : DATE NOTE ACCOUNT STRING eol
      {
          $$ = BUILD("note", "siOOO", FILE_LINE_ARGS, $1, $3, $4);
          DECREF3($1, $3, $4);
      }

filename : STRING

document : DATE DOCUMENT ACCOUNT filename eol
      {
          $$ = BUILD("document", "siOOO", FILE_LINE_ARGS, $1, $3, $4);
          DECREF3($1, $3, $4);
      }

entry : transaction
      | check
      | open
      | close
      | pad
      | event
      | note
      | document
      | price
      {
          $$ = $1;
      }

option : OPTION STRING STRING eol
       {
          BUILD("option", "siOO", FILE_LINE_ARGS, $2, $3);
          DECREF2($2, $3);
       }

directive : SKIPPED
          | empty_line
          | pushtag
          | poptag
          | option


declarations : declarations directive
             {
                 $$ = $1;
             }
             | declarations entry
             {
                 $$ = BUILD("handle_list", "OO", $1, $2);
                 DECREF2($1, $2);
             }
             | declarations error
             {
                 $$ = $1;
             }
             | empty
             {
                  Py_INCREF(Py_None);
                  $$ = Py_None;
             }

file : declarations
     {
         BUILD("store_result", "O", $1);
     }


/*--------------------------------------------------------------------------------*/
/* Epilogue */
%%

/* A function that will convert a token name to a string, used in debugging. */
const char* getTokenName(int token)
{
    switch ( token ) {
        case ERROR    : return "ERROR";
        case INDENT   : return "INDENT";
        case EOL      : return "EOL";
        case COMMENT  : return "COMMENT";
        case SKIPPED  : return "SKIPPED";
        case PIPE     : return "PIPE";
        case ATAT     : return "ATAT";
        case AT       : return "AT";
        case LCURL    : return "LCURL";
        case RCURL    : return "RCURL";
        case EQUAL    : return "EQUAL";
        case COMMA    : return "COMMA";
        case SLASH    : return "SLASH";
        case FLAG     : return "FLAG";
        case TXN      : return "TXN";
        case CHECK    : return "CHECK";
        case OPEN     : return "OPEN";
        case CLOSE    : return "CLOSE";
        case PAD      : return "PAD";
        case EVENT    : return "EVENT";
        case PRICE    : return "PRICE";
        case NOTE     : return "NOTE";
        case DOCUMENT : return "DOCUMENT";
        case PUSHTAG  : return "PUSHTAG";
        case POPTAG   : return "POPTAG";
        case OPTION   : return "OPTION";
        case DATE     : return "DATE";
        case ACCOUNT  : return "ACCOUNT";
        case CURRENCY : return "CURRENCY";
        case STRING   : return "STRING";
        case NUMBER   : return "NUMBER";
        case TAG      : return "TAG";
        case LINK     : return "LINK";
    }
    return 0;
}