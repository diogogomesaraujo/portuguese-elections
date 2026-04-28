%{
    open Pg
%}

%token <float> FLOAT

%token EOF
%token POLYGON
%token MULTIPOLYGON
%token COMMA
%token LPAR
%token RPAR

%start <Pg.wkt_term> prog
%%

prog:
  | e = expr; EOF { e }
  ;

point:
  | i1 = FLOAT; i2 = FLOAT; { (i1, i2) }
  ;

point_list:
  | LPAR; l = separated_list(COMMA, point); RPAR; { l }
  ;

point_list_list:
  | LPAR; l = separated_list(COMMA, point_list) RPAR; { l }
  ;

expr:
  | POLYGON; l = point_list_list; { Polygon l }
  | MULTIPOLYGON; LPAR; l = separated_list(COMMA, point_list_list); RPAR; { Multipolygon l }
  ;
