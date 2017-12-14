%{
%}

(* Infix operations a la OCaml *)
%token <Name.ident Location.located> PREFIXOP INFIXOP0 INFIXOP1 INFIXOP2 INFIXOP3 INFIXOP4

(* Names and constants *)
%token <Name.ident> NAME
(*
%token <int> NUMERAL
*)

(* Parentheses & punctuations *)
%token LPAREN RPAREN PERIOD
%token COLONEQ
%token COMMA COLON DARROW

(*
%token SEMICOLON
%token COLON ARROW
%token BAR DARROW
*)

(* Expressions *)
%token TYPE
%token PROD
%token LAMBDA

(* Toplevel commands *)

%token <string> QUOTED_STRING
%token LOAD
%token DEFINITION
%token CHECK
%token EVAL
%token AXIOM

(* End of input token *)
%token EOF

(* Precedence and fixity of infix operators *)
(* %left     INFIXOP0
 * %right    INFIXOP1
 * %left     INFIXOP2
 * %left     INFIXOP3
 * %right    INFIXOP4 *)

%start <Input.toplevel list> file
%start <Input.toplevel> commandline

%%

(* Toplevel syntax *)

file:
  | f=filecontents EOF            { f }

filecontents:
  |                                   { [] }
  | d=topcomp PERIOD ds=filecontents  { d :: ds }

commandline:
  | topcomp PERIOD EOF       { $1 }

(* Things that can be defined on toplevel. *)
topcomp: mark_location(plain_topcomp) { $1 }
plain_topcomp:
  | LOAD fn=QUOTED_STRING                { Input.TopLoad fn }
  | DEFINITION x=var_name COLONEQ e=term { Input.TopDefinition (x, e) }
  | CHECK e=term                         { Input.TopCheck e }
  | EVAL e=term                          { Input.TopEval e }
  | AXIOM x=var_name COLON e=term        { Input.TopAxiom (x, e) }

(* Main syntax tree *)
term : mark_location(plain_term) { $1 }
plain_term:
  | e=plain_app_term                     { e }
  | PROD a=abstraction COMMA e=term      { Input.Prod (a, e) }
  | LAMBDA a=abstraction DARROW e=term   { Input.Lambda (a, e) }

app_term: mark_location(plain_app_term) { $1 }
plain_app_term:
  | e=plain_prefix_term          { e }
  | e1=app_term e2=prefix_term   { Input.Apply (e1, e2) }

prefix_term: mark_location(plain_prefix_term) { $1 }
plain_prefix_term:
  | e=plain_simple_term                       { e }
  | oploc=prefix e2=prefix_term
    { let {Location.data=op; loc} = oploc in
      let op = Location.locate ~loc (Input.Var op) in
      Input.Apply (op, e2)
    }

(* simple_term : mark_location(plain_simple_term) { $1 } *)
plain_simple_term:
  | LPAREN e=plain_term RPAREN         { e }
  | TYPE                               { Input.Type }
  | x=var_name                         { Input.Var x }

var_name:
  | NAME                     { $1 }
  | LPAREN op=infix RPAREN   { op.Location.data }
  | LPAREN op=prefix RPAREN  { op.Location.data }

%inline infix:
  | op=INFIXOP0    { op }
  | op=INFIXOP1    { op }
  | op=INFIXOP2    { op }
  | op=INFIXOP3    { op }
  | op=INFIXOP4    { op }

%inline prefix:
  | op=PREFIXOP { op }

abstraction:
  | lst=nonempty_list(abstract1)  { lst }

abstract1:
  | LPAREN xs=nonempty_list(var_name) COLON t=term RPAREN { (xs, t) }

mark_location(X):
  x=X
  { Location.locate ~loc:(Location.make $startpos $endpos) x }
%%