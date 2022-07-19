
open Cabs

let nextident = ref 0
let getident () =
    nextident := !nextident + 1;
    !nextident

let currentLoc () =
  let l, f, c, lc = Errormsg.getPosition () in
  { lineno   = l;
    filename = f;
    byteno   = c;
    columnno = c - lc;
    ident    = getident ();
    endLineno = -1;
    endByteno = -1;
    endColumnno = -1;}

let cabslu = {lineno = -10;
	      filename = "cabs loc unknown";
	      byteno = -10; columnno = -10;
              ident = 0;
              endLineno = -10; endByteno = -10; endColumnno = -10;}

let string_of_loc l =
  Printf.sprintf "%s:%d:%d-%d:%d" l.filename l.lineno l.columnno l.endLineno l.endColumnno

let joinLoc l1 l2 = match l1, l2 with
  | l1, l2 when l1.filename = l2.filename && l1.endByteno < 0 && l2.endByteno < 0 && l1.byteno <= l2.byteno ->
    {l1 with endLineno = l2.lineno; endByteno = l2.byteno; endColumnno = l2.columnno}
  | l1, l2 when l1.filename = l2.filename && l1.endByteno < l2.byteno && l2.endByteno < 0 && l1.byteno <= l2.byteno ->
    {l1 with endLineno = l2.lineno; endByteno = l2.byteno; endColumnno = l2.columnno}
  | l1, l2 when l1.filename = l2.filename && l1.endByteno = l2.endByteno && l1.byteno = l2.byteno ->
    l1 (* alias fundefs *)
  | _, _ ->
    (* some code generators leave start and end into different files: https://github.com/goblint/cil/issues/54 *)
    Errormsg.warn "joinLoc %s %s" (string_of_loc l1) (string_of_loc l2);
    l1 (* no way to give an actual range *)

(* clexer puts comments here *)
let commentsGA = GrowArray.make 100 (GrowArray.Elem(cabslu,"",false))


(*********** HELPER FUNCTIONS **********)

let missingFieldDecl = ("___missing_field_name", JUSTBASE, [], cabslu)

let rec isStatic = function
    [] -> false
  | (SpecStorage STATIC) :: _ -> true
  | _ :: rest -> isStatic rest

let rec isExtern = function
    [] -> false
  | (SpecStorage EXTERN) :: _ -> true
  | _ :: rest -> isExtern rest

let rec isInline = function
    [] -> false
  | SpecInline :: _ -> true
  | _ :: rest -> isInline rest

let rec isTypedef = function
    [] -> false
  | SpecTypedef :: _ -> true
  | _ :: rest -> isTypedef rest


let get_definitionloc (d : definition) : cabsloc =
  match d with
  | FUNDEF(_, _, l, _) -> l
  | DECDEF(_, l) -> l
  | TYPEDEF(_, l) -> l
  | ONLYTYPEDEF(_, l) -> l
  | GLOBASM(_, l) -> l
  | PRAGMA(_, l) -> l
  | TRANSFORMER(_, _, l) -> l
  | EXPRTRANSFORMER(_, _, l) -> l
  | LINKAGE (_, l, _) -> l
  | STATIC_ASSERT (_,_,l) -> l

let get_statementloc (s : statement) : cabsloc =
begin
  match s with
  | NOP(loc) -> loc
  | COMPUTATION(_,loc) -> loc
  | BLOCK(_,loc) -> loc
  | SEQUENCE(_,_,loc) -> loc
  | IF(_,_,_,loc,_) -> loc
  | WHILE(_,_,loc,_) -> loc
  | DOWHILE(_,_,loc,_) -> loc
  | FOR(_,_,_,_,loc,_) -> loc
  | BREAK(loc) -> loc
  | CONTINUE(loc) -> loc
  | RETURN(_,loc) -> loc
  | SWITCH(_,_,loc,_) -> loc
  | CASE(_,_,loc,_) -> loc
  | CASERANGE(_,_,_,loc,_) -> loc
  | DEFAULT(_,loc,_) -> loc
  | LABEL(_,_,loc) -> loc
  | GOTO(_,loc) -> loc
  | COMPGOTO (_, loc) -> loc
  | DEFINITION d -> get_definitionloc d
  | ASM(_,_,_,loc) -> loc
end


let explodeStringToInts (s: string) : int64 list =
  let rec allChars i acc =
    if i < 0 then acc
    else allChars (i - 1) (Int64.of_int (Char.code (String.get s i)) :: acc)
  in
  allChars (-1 + String.length s) []

let valueOfDigit chr =
  let int_value =
    match chr with
      '0'..'9' -> (Char.code chr) - (Char.code '0')
    | 'a'..'z' -> (Char.code chr) - (Char.code 'a') + 10
    | 'A'..'Z' -> (Char.code chr) - (Char.code 'A') + 10
    | _ -> Errormsg.s (Errormsg.bug "not a digit") in
  Int64.of_int int_value


open Pretty
let d_cabsloc () cl =
  text cl.filename ++ text ":" ++ num cl.lineno
