{
open Parser
}

let white = [' ' '\t' '\r' '\n']+
let digit = ['0'-'9']
let float = '-'? digit+ ('.' digit+)?

rule read =
    parse
    | white { read lexbuf }
    | float { FLOAT (float_of_string (Lexing.lexeme lexbuf))}
    | "(" { LPAR }
    | ")" { RPAR }
    | "," { COMMA }
    | "POLYGON" { POLYGON }
    | "MULTIPOLYGON" { MULTIPOLYGON }
    | eof { EOF }
