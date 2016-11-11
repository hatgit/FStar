%{

(* (c) Microsoft Corporation. All rights reserved *)

(* TO BE ADDED IN parse.fsy
open Prims
open FStar.List
open FStar.Util
open FStar.Range
open FStar.Options
open FStar.Absyn.Syntax
open FStar.Absyn.Const
open FStar.Absyn.Util
open FStar.Parser.AST
open FStar.Parser.Util
open FStar.Const
open FStar.Ident
*)

open Prims
open FStar_List
open FStar_Util
open FStar_Range
open FStar_Options
open FStar_Absyn_Syntax
open FStar_Absyn_Const
open FStar_Absyn_Util
open FStar_Parser_AST
open FStar_Parser_Util
open FStar_Const
open FStar_Ident

let as_frag d ds =
    let rec as_mlist out ((m,r,doc), cur) ds =
    match ds with
    | [] -> List.rev (Module(m, (mk_decl (TopLevelModule(m)) r doc) ::(List.rev cur))::out)
    | d::ds ->
      begin match d.d with
        | TopLevelModule m' ->
				as_mlist (Module(m, (mk_decl (TopLevelModule(m)) r doc) :: (List.rev cur))::out) ((m',d.drange,d.doc), []) ds
        | _ -> as_mlist out ((m,r,doc), d::cur) ds
      end in
    match d.d with
    | TopLevelModule m ->
        let ms = as_mlist [] ((m,d.drange,d.doc), []) ds in
        begin match ms with
        | _::Module(n, _)::_ ->
		(* This check is coded to hard-fail in dep.num_of_toplevelmods. *)
        let msg = "Support for more than one module in a file is deprecated" in
        print2_warning "%s (Warning): %s\n" (string_of_range (range_of_lid n)) msg
        | _ -> ()
        end;
        Inl ms
    | _ ->
        let ds = d::ds in
        iter (function {d=TopLevelModule _; drange=r} -> raise (Error("Unexpected module declaration", r))
                       | _ -> ()) ds;
        Inr ds

let extendTuplePat pat pats =
  match pats.pat with
  | PatTuple (l, false) -> PatTuple (pat::l, false)
  | _ -> PatTuple ([pat; pats], false)

let refine_for_pattern t phi_opt pat pos_t pos =
  begin match phi_opt, pat.pat with
  | None, _ -> t
  | Some phi,  PatVar(x, _) ->
     mk_term (Refine(mk_binder (Annotated(x, t)) pos_t Type None, phi)) pos Type
  | Some _, _ ->
     errorR(Error("Not a valid refinement type", lhs(parseState))); t
  end

%}

%token <bytes> BYTEARRAY
%token <bytes> STRING
%token <string> IDENT
%token <string> NAME
%token <string> TVAR
%token <string> TILDE

/* bool indicates if INT8 was 'bad' max_int+1, e.g. '128'  */
%token <string * bool> INT8
%token <string * bool> INT16
%token <string * bool> INT32
%token <string * bool> INT64
%token <string * bool> INT

%token <string> UINT8
%token <string> UINT16
%token <string> UINT32
%token <string> UINT64
%token <float> IEEE64
%token <char> CHAR
%token <bool> LET
%token <FStar_Parser_AST.fsdoc> FSDOC
%token <FStar_Parser_AST.fsdoc> FSDOC_STANDALONE

%token FORALL EXISTS ASSUME NEW LOGIC
%token IRREDUCIBLE UNFOLDABLE INLINE OPAQUE ABSTRACT UNFOLD INLINE_FOR_EXTRACTION
%token NOEQUALITY UNOPTEQUALITY PRAGMALIGHT PRAGMA_SET_OPTIONS PRAGMA_RESET_OPTIONS
%token ACTIONS TYP_APP_LESS TYP_APP_GREATER SUBTYPE SUBKIND
%token AND ASSERT BEGIN ELSE END
%token EXCEPTION FALSE L_FALSE FUN FUNCTION IF IN MODULE DEFAULT
%token MATCH OF
%token OPEN REC MUTABLE THEN TRUE L_TRUE TRY TYPE EFFECT VAL
%token WHEN WITH HASH AMP LPAREN RPAREN LPAREN_RPAREN COMMA LARROW RARROW
%token IFF IMPLIES CONJUNCTION DISJUNCTION
%token DOT COLON COLON_COLON SEMICOLON
%token SEMICOLON_SEMICOLON EQUALS PERCENT_LBRACK DOT_LBRACK DOT_LPAREN LBRACK LBRACK_BAR LBRACE BANG_LBRACE
%token BAR_RBRACK UNDERSCORE LENS_PAREN_LEFT LENS_PAREN_RIGHT
%token BAR RBRACK RBRACE DOLLAR
%token PRIVATE REIFIABLE REFLECTABLE REIFY LBRACE_COLON_PATTERN PIPE_RIGHT
%token NEW_EFFECT NEW_EFFECT_FOR_FREE SUB_EFFECT SQUIGGLY_RARROW TOTAL KIND
%token REQUIRES ENSURES
%token MINUS COLON_EQUALS
%token BACKTICK

%token<string>  OPPREFIX OPINFIX0a OPINFIX0b OPINFIX0c OPINFIX0d OPINFIX1 OPINFIX2 OPINFIX3 OPINFIX4

/* These are artificial */
%token EOF

%nonassoc THEN
%nonassoc ELSE

/********************************************************************************/
/* TODO : check that precedence of the following section mix well with the rest */
%right IFF
%right IMPLIES

%left DISJUNCTION
%left CONJUNCTION

%right COMMA
%right COLON_COLON
%right AMP
/********************************************************************************/

%nonassoc COLON_EQUALS
%left     OPINFIX0a
%left     OPINFIX0b
%left     OPINFIX0c EQUALS
%left     OPINFIX0d
%left     PIPE_RIGHT
%right    OPINFIX1
%left     OPINFIX2 MINUS
%left     OPINFIX3
%left     BACKTICK
%right    OPINFIX4

%start inputFragment
%start term
%type <inputFragment> inputFragment
%type <term> term

%type <FStar_Ident.ident> ident

%%

inputFragment:
  | option(PRAGMALIGHT STRING {}) md=moduleDecl decls=list(decl) main_opt=mainDecl? EOF
       {
         let decls = match main_opt with
           | None -> decls
           | Some main -> decls @ [main]
         in as_frag md decls
       }

moduleDecl:
  | doc_opt=FSDOC? MODULE module_name=qname
     { mk_decl (TopLevelModule module_name) (rhs2 parseState 1 2) doc_opt }

mainDecl:
  | SEMICOLON_SEMICOLON doc_opt=FSDOC? t=term
      { mk_decl (Main t) (rhs2 parseState 1 3) doc_opt }


/******************************************************************************/
/*                      Top level declarations                                */
/******************************************************************************/

pragma:
  | PRAGMA_SET_OPTIONS s=string
      { SetOptions s }
  | PRAGMA_RESET_OPTIONS s_opt=string?
      { ResetOptions s_opt }

decl:
  | fsdoc_opt=FSDOC? decl=decl2 { mk_decl decl (rhs parseState 2) fsdoc_opt }

decl2:
  | OPEN qname
      { Open $2 }
  | MODULE name EQUALS qname
      {  ModuleAbbrev($2, $4) }
(* Seems to be deprecated *)
(*  | MODULE qname
             {  TopLevelModule $2  } *)
  | kind_abbrev
      { $1 }
  | tycon
      { $1 }
  | qs=qualifiers LET lq=letqualifier lb=letbinding lbs=letbindings
      {
        let r, focus = lq in
        let lbs = focusLetBindings ((focus, lb)::lbs) (rhs2 parseState 1 5) in
        ToplevelLet(qs, r, lbs)
      }
  | qs=qualifiers VAL lid=ident COLON t=typ
      { Val(qs, lid, t) }
  | tag=assumeTag lid=name COLON phi=formula
      { Assume(tag, lid, phi) }
  | EXCEPTION lid=name t_opt=option(OF t=typ {t})
      { Exception(lid, t_opt) }
  | qs=qualifiers NEW_EFFECT ne=new_effect
      { NewEffect (qs, ne) }
  | qs=qualifiers SUB_EFFECT se=sub_effect
      { SubEffect se } (* TODO (KM) : Why are we dropping the qualifiers here ? Does that mean we should not accept them ? *)
  | qs=qualifiers NEW_EFFECT_FOR_FREE ne=new_effect
      { NewEffectForFree (qs, ne) }
  | p=pragma
      { Pragma p }
  | doc=FSDOC_STANDALONE
      { Fsdoc doc }

tycon:
  (* This rule accepts a documentation on the first type which was prohibited before (why ?) *)
  | qs=qualifiers TYPE tcdefs=list(pair(option(FSDOC), tyconDefinition))
      { Tycon (qs, List.map (fun (doc, f) -> (f false, doc)) tcdefs) }

  | qs=qualifiers EFFECT tcdef=tyconDefinition
      { Tycon(Effect::qs, [(tcdef true, None)]) }

tyconDefinition:
  | lid=eitherName tparams=typars ascr_opt=ascribeKind? tcdef=tyconDefn
      { tcdef lid tparams ascr_opt }

typars:
  | x=tvarinsts              { x }
  | x=binders                { x }

tvarinsts:
  | TYP_APP_LESS tvs=separated_nonempty_list(COMMA, tvar) TYP_APP_GREATER
      { map (fun tv -> mk_binder (TVariable(tv)) tv.idRange Kind None) tvs }

tyconDefn:
  |   { (fun id binders kopt eff -> if not eff then check_id id; TyconAbstract(id, binders, kopt)) }
  | EQUALS t=typ
      { (fun id binders kopt eff -> if not eff then check_id id; TyconAbbrev(id, binders, kopt, t)) }
  /* A documentation on the first branch creates a conflict with { x with a = ... }/{ a = ... } */
  | EQUALS LBRACE
      decl0=separated_pair(ident, COLON, typ)
      record_field_decls=separated_list(SEMICOLON, recordFieldDecl) SEMICOLON?
   RBRACE
   {
     let (lid, t) = decl0 in
     (fun id binders kopt eff ->
       if not eff then check_id id; TyconRecord(id, binders, kopt, (lid, t, None)::record_field_decls))
   }
  | EQUALS ct_decls=list(constructorDecl)
      { (fun id binders kopt eff -> if not eff then check_id id; TyconVariant(id, binders, kopt, ct_decls)) }

recordFieldDecl:
  | doc_opt=FSDOC? lid=ident COLON t=typ { (lid, t, doc_opt) }

constructorDecl:
  | BAR doc_opt=FSDOC? uid=name COLON t=typ                { (uid, Some t, doc_opt, false) }
  | BAR doc_opt=FSDOC? uid=name t_opt=option(OF t=typ {t}) { (uid, t_opt, doc_opt, true) }

kind_abbrev:
  | KIND lid=eitherName bs=binders EQUALS k=kind
      { KindAbbrev(lid, bs, k) }

letbindings:
  | lbs=separated_list(AND, pair(maybeFocus,letbinding)) { lbs }

letbinding:
  | lid=ident lbp=nonempty_list(bindingPattern) ascr_opt=ascribeTyp? EQUALS tm=term
      {
        let pat = mk_pattern (PatVar(lid, None)) (rhs parseState 1) in
        let pat = mk_pattern (PatApp (pat, flatten lbp)) (rhs2 parseState 1 2) in
        let pos = rhs2 parseState 1 5 in
        match ascr_opt with
        | None -> (pat, tm)
        | Some t -> (mk_pattern (PatAscribed(pat, t)) pos, tm)
      }
  | pat=pattern ascr=ascribeTyp EQUALS tm=term
      { (mk_pattern (PatAscribed(pat, ascr)) (rhs2 parseState 1 4), tm) }
  | pat=pattern EQUALS tm=term
      { (pat, tm) }

/******************************************************************************/
/*                                Effects                                     */
/******************************************************************************/

new_effect:
  | ed=effect_redefinition
  | ed=effect_definition
       { ed }

effect_redefinition:
  | lid=name EQUALS t=simpleTerm
      { RedefineEffect(lid, [], t) }

effect_definition:
  | LBRACE lid=name bs=binders COLON k=kind
    	   WITH eds=separated_nonempty_list(SEMICOLON, effect_decl)
		     AND ACTIONS actions=separated_nonempty_list(SEMICOLON, effect_decl)
    RBRACE
      {
         DefineEffect(lid, bs, k, eds, actions)
      }

effect_decl:
  | lid=ident EQUALS t=simpleTerm
     { mk_decl (Tycon ([], [(TyconAbbrev(lid, [], None, t), None)])) (rhs2 parseState 1 3) None }

sub_effect:
  | src_eff=qname SQUIGGLY_RARROW tgt_eff=qname EQUALS lift=simpleTerm
      { { msource = src_eff; mdest = tgt_eff; lift_op = NonReifiableLift lift } }
  | src_eff=qname SQUIGGLY_RARROW tgt_eff=qname
    LBRACE
      lift1=separated_pair(IDENT, EQUALS, simpleTerm)
      lift2_opt=separated_pair(IDENT, EQUALS, simpleTerm)?
    RBRACE
     {
       match lift2_opt with
       | None ->
          begin match lift1 with
          | ("lift", lift) ->
             { msource = src_eff; mdest = tgt_eff; lift_op = LiftForFree lift }
          | ("lift_wp", lift_wp) ->
             { msource = src_eff; mdest = tgt_eff; lift_op = NonReifiableLift lift_wp }
          | _ ->
             raise (Error("Unexpected identifier; expected {'lift', and possibly 'lift_wp'}", lhs parseState))
          end
       | Some (id2, tm2) ->
          let (id1, tm1) = lift1 in
          let lift, lift_wp = match (id1, id2) with
	          | "lift_wp", "lift" -> tm1, tm2
	          | "lift", "lift_wp" -> tm2, tm1
	          | _ -> raise (Error("Unexpected identifier; expected {'lift', 'lift_wp'}", lhs parseState))
          in
          { msource = src_eff; mdest = tgt_eff; lift_op = ReifiableLift (lift, lift_wp) }
     }


/******************************************************************************/
/*                        Qualifiers, tags, ...                               */
/******************************************************************************/

qualifier:
  | ASSUME        { Assumption }
  | INLINE        {
    (* KM : We are raising before returning some value ? *)
    raise (Error("The 'inline' qualifier has been renamed to 'unfold'", lhs parseState));
	  Inline
   }
  | UNFOLDABLE    {
	      raise (Error("The 'unfoldable' qualifier is no longer denotable; it is the default qualifier so just omit it", lhs parseState))
   }
  | INLINE_FOR_EXTRACTION {
     Inline_for_extraction
  }
  | UNFOLD {
     Unfold_for_unification_and_vcgen
  }
  | IRREDUCIBLE   { Irreducible }
  | DEFAULT       { DefaultEffect }
  | TOTAL         { TotalEffect }
  | PRIVATE       { Private }
  | ABSTRACT      { Abstract }
  | NOEQUALITY    { Noeq }
  | UNOPTEQUALITY { Unopteq }
  | NEW           { New }
  | LOGIC         { Logic }
  | OPAQUE        { Opaque }
  | REIFIABLE     { Reifiable }
  | REFLECTABLE   { Reflectable }

%inline qualifiers:
  | qs=list(qualifier) { qs }

assumeTag:
  | ASSUME { [Assumption] }


maybeFocus:
  | b=boption(SQUIGGLY_RARROW) { b }

letqualifier:
  | b=maybeFocus REC    { Rec, b }
  | MUTABLE             { Mutable, false }
  |                     { NoLetQualifier, false }

aqual:
  | HASH      { Implicit }
  | EQUALS    { if universes()
                then print1 "%s (Warning): The '=' notation for equality constraints on binders is deprecated; use '$' instead\n" (string_of_range (lhs parseState));
				Equality }
  | DOLLAR    { Equality }


/******************************************************************************/
/*                         Patterns, binders                                  */
/******************************************************************************/

pattern:
  | pat=openPatternRec1 { pat }

openPatternRec1:
  | pat=openPatternRec1 COMMA pats=openPatternRec1
      { mk_pattern (extendTuplePat pat pats) (rhs2 parseState 1 3) }
  | pat=openPatternRec2
      { pat }

openPatternRec2:
  | pat=openPatternRec2 COLON_COLON pats=openPatternRec2
      { mk_pattern (consPat (rhs parseState 3) pat pats) (rhs2 parseState 1 3) }
  | pat=patternRec
      { pat }

patternRec:
  | LBRACK pats=separated_list(SEMICOLON, openPatternRec1) RBRACK
      { mk_pattern (PatList pats) (rhs2 parseState 1 3) }
  | LBRACE record_pat=separated_nonempty_list(SEMICOLON, separated_pair(lid, EQUALS, openPatternRec1)) RBRACE
      { mk_pattern (PatRecord record_pat) (rhs2 parseState 1 4) }
  | LENS_PAREN_LEFT pat0=openPatternRec2 COMMA pats=separated_nonempty_list(COMMA, openPatternRec2) LENS_PAREN_RIGHT
      { mk_pattern (PatTuple(pat0::pats, true)) (rhs2 parseState 1 5) }
  | LPAREN pat=pattern RPAREN   { pat }
  | LPAREN pat=pattern COLON t=typ phi_opt=refineOpt RPAREN
      {
        let pos_t = rhs2 parseState 2 4 in
        let pos = rhs2 parseState 2 5 in
        mk_pattern (PatAscribed(pat, refine_for_pattern t phi_opt pat pos_t pos)) (rhs2 parseState 1 6)
      }
  | tv=tvar                   { mk_pattern (PatTvar (tv, None)) (rhs parseState 1) }
  | pat=operatorPattern
      { pat }
  | UNDERSCORE
      { mk_pattern PatWild (rhs parseState 1) }
  | c=constant
      { mk_pattern (PatConst c) (rhs parseState 1) }
  | HASH lid=ident
      { mk_pattern (PatVar (lid, Some Implicit)) (rhs2 parseState 1 2) }
  | DOLLAR lid=ident
      { mk_pattern (PatVar (lid, Some Equality)) (rhs2 parseState 1 2)}
  | lid=ident
      { mk_pattern (PatVar (lid, None)) (rhs parseState 1)}
  | uid=qname
      { mk_pattern (PatName uid) (rhs parseState 1) }

operatorPattern:
  | LPAREN OPPREFIX RPAREN
      { mk_pattern (PatOp($2)) (rhs2 parseState 1 3) }
  | LPAREN OPINFIX0a RPAREN
      { mk_pattern (PatOp($2)) (rhs2 parseState 1 3) }
  | LPAREN OPINFIX0b RPAREN
      { mk_pattern (PatOp($2)) (rhs2 parseState 1 3) }
  | LPAREN OPINFIX0c RPAREN
      { mk_pattern (PatOp($2)) (rhs2 parseState 1 3) }
  | LPAREN OPINFIX0d RPAREN
      { mk_pattern (PatOp($2)) (rhs2 parseState 1 3) }
  | LPAREN OPINFIX1 RPAREN
      { mk_pattern (PatOp($2)) (rhs2 parseState 1 3) }
  | LPAREN OPINFIX2 RPAREN
      { mk_pattern (PatOp($2)) (rhs2 parseState 1 3) }
  | LPAREN OPINFIX3 RPAREN
      { mk_pattern (PatOp($2)) (rhs2 parseState 1 3) }
  | LPAREN OPINFIX4 RPAREN
      { mk_pattern (PatOp($2)) (rhs2 parseState 1 3) }

bindingPattern:
  | pat=patternRec { [pat] }
  | LPAREN pat=pattern RPAREN { [pat] }
  /* TODO : multiple binders in binding pattern */
/*  | LPAREN pats=nonempty_list(ascriptionFreePattern) COLON t=typ phi_opt=refineOpt RPAREN
      {
        List.map (fun pat ->
                 mk_term (Refine(mk_binder (Annotated(x, t)) pos_t Type None, phi)) pos Type
          )
      }*/

binder:
  | lid=ident { [mk_binder (Variable lid) (rhs parseState 1) Type None]  }
  | tv=tvar  { [mk_binder (TVariable tv) (rhs parseState 1) Kind None]  }
  | LPAREN qual_lids=nonempty_list(pair(option(aqual), ident)) COLON t=typ r=refineOpt RPAREN
          { List.map (fun (q, x) -> mkRefinedBinder x t r (rhs2 parseState 1 5) q) qual_lids }

binders: bs=list(binder) { flatten bs }



/******************************************************************************/
/*                      Identifiers, module paths                             */
/******************************************************************************/

lid:
  | ids=path(ident) { lid_of_ids ids }

qname:
  | ids=path(name) { lid_of_ids ids }

eitherQname:
  | ids=path(eitherName) { lid_of_ids ids }

path(Id):
  | id=Id { [id] }
  | uid=name DOT p=path(Id) { uid::p }

eitherName:
  | x=ident { x }
  | x=name  { x }

ident:
  | id=IDENT { mk_ident(id, rhs parseState 1)}

name:
  | id=NAME { mk_ident(id, rhs parseState 1) }

tvar:
  | tv=TVAR { mk_ident(tv, rhs parseState 1) }


/******************************************************************************/
/*                            Types and terms                                 */
/******************************************************************************/

ascribeTyp:
  | COLON t=tmArrow(tmNoEq) { t }

ascribeKind:
  | COLON  k=kind { k }

kind:
  | t=tmArrow(tmNoEq) { {t with level=Kind} }

typ:
  | t=simpleTerm  { t }

  | FORALL bs=binders DOT trigger=qpat e=noSeqTerm
      {
        match bs with
            | [] -> raise (Error("Missing binders for a quantifier", rhs2 parseState 1 3))
            | _ -> mk_term (QForall(bs, trigger, e)) (rhs2 parseState 1 5) Formula
      }

  | EXISTS bs=binders DOT trigger=qpat e=noSeqTerm
      {
        match bs with
            | [] -> raise (Error("Missing binders for a quantifier", rhs2 parseState 1 3))
            | _ -> mk_term (QExists(bs, trigger, e)) (rhs2 parseState 1 5) Formula
      }


term:
  | e=noSeqTerm
      { e }
  | e1=noSeqTerm SEMICOLON e2=term
      { mk_term (Seq(e1, e2)) (rhs2 parseState 1 3) Expr }


noSeqTerm:
  | t=typ  { t }
  | e1=atomicTerm DOT_LBRACK e2=term RBRACK LARROW e3=noSeqTerm
      { mk_term (Op(".[]<-", [ e1; e2; e3 ])) (rhs2 parseState 1 6) Expr }
  | e1=atomicTerm DOT_LPAREN e2=term RPAREN LARROW e3=noSeqTerm
      { mk_term (Op(".()<-", [ e1; e2; e3 ])) (rhs2 parseState 1 6) Expr }
  | REQUIRES t=typ
      { mk_term (Requires(t, None)) (rhs2 parseState 1 2) Type }
  | ENSURES t=typ
      { mk_term (Ensures(t, None)) (rhs2 parseState 1 2) Type }
  | IF e1=noSeqTerm THEN e2=noSeqTerm ELSE e3=noSeqTerm
      { mk_term (If(e1, e2, e3)) (rhs2 parseState 1 6) Expr }
  | IF e1=noSeqTerm THEN e2=noSeqTerm
      {
        let e3 = mk_term (Const Const_unit) (rhs2 parseState 4 4) Expr in
        mk_term (If(e1, e2, e3)) (rhs2 parseState 1 4) Expr
      }
  | TRY e1=term WITH pb=firstPatternBranch pbs=patternBranches
      {
         let branches = focusBranches (pb::pbs) (rhs2 parseState 1 5) in
         mk_term (TryWith(e1, branches)) (rhs2 parseState 1 5) Expr
      }
  | MATCH e=term WITH pbs=patternBranches
      {
        let branches = focusBranches pbs (rhs2 parseState 1 4) in
        mk_term (Match(e, branches)) (rhs2 parseState 1 4) Expr
      }
  | LET OPEN uid=qname IN e=term
      { mk_term (LetOpen(uid, e)) (rhs2 parseState 1 5) Expr }
  | LET q=letqualifier lb=letbinding lbs=letbindings IN e=term
      {
        let r, focus = q in
        let lbs = focusLetBindings ((focus,lb)::lbs) (rhs2 parseState 2 4) in
        mk_term (Let(r, lbs, e)) (rhs2 parseState 1 6) Expr
      }
  | FUNCTION pb=firstPatternBranch pbs=patternBranches
      {
        let branches = focusBranches (pb::pbs) (rhs2 parseState 1 3) in
        mk_function branches (lhs parseState) (rhs2 parseState 1 3)
      }
  | ASSUME e=atomicTerm
      { mkExplicitApp (mk_term (Var assume_lid) (rhs parseState 1) Expr) [e] (rhs2 parseState 1 2) }
  | id=ident LARROW e=noSeqTerm
      { mk_term (Assign(id, e)) (rhs2 parseState 1 3) Expr }

qpat:
  |   { [] }
  | LBRACE_COLON_PATTERN pats=disjunctivePats RBRACE { pats }

disjunctivePats:
  | pats=separated_nonempty_list(DISJUNCTION, conjunctivePat) { pats }

conjunctivePat:
  | pats=separated_nonempty_list(SEMICOLON, appTerm)          { pats }

simpleTerm:
  | e=tmIff { e }
  | FUN pats=nonempty_list(bindingPattern) RARROW e=term
      { mk_term (Abs(flatten pats, e)) (rhs2 parseState 1 4) Un }

patternBranches:
  | pbs=list(patternBranch) { pbs }

maybeFocusArrow:
  | RARROW          { false }
  | SQUIGGLY_RARROW { true }

firstPatternBranch: /* shift/reduce conflict on BAR ... expected for nested matches */
  | pb=patternBranchSep(BAR?) { pb }

patternBranch: /* shift/reduce conflict on BAR ... expected for nested matches */
  | pb=patternBranchSep(BAR) { pb }

%inline patternBranchSep(SEP):
  | SEP pat=disjunctivePattern when_opt=maybeWhen focus=maybeFocusArrow e=term
      {
        let pat = match pat with
          | [p] -> p
          | ps -> mk_pattern (PatOr ps) (rhs2 parseState 1 2)
        in
        (focus, (pat, when_opt, e))
      }

%inline maybeWhen:
  |                      { None }
  | WHEN e=tmFormula     { Some e }


disjunctivePattern:
  | pats=separated_nonempty_list(BAR, pattern) { pats }

tmIff:
  | e1=tmIff IFF e2=tmIff
      { mk_term (Op("<==>", [e1; e2])) (rhs2 parseState 1 3) Formula }
  | e1=tmIff IMPLIES e2=tmIff
      { mk_term (Op("==>", [e1; e2])) (rhs2 parseState 1 3) Formula }
  | e=tmArrow(tmFormula)
      { e }


(* Tm : tmDisjunction (now tmFormula, with equals) or tmCons (now tmNoEq, without equals) *)
tmArrow(Tm):
  | aq_opt=aqual? dom_tm=Tm RARROW tgt=tmArrow(Tm)
     {
        let b = match extract_named_refinement dom_tm with
            | None -> mk_binder (NoName dom_tm) (rhs parseState 1) Un aq_opt
            | Some (x, t, f) -> mkRefinedBinder x t f (rhs2 parseState 1 1) aq_opt
        in
        mk_term (Product([b], tgt)) (rhs2 parseState 1 3)  Un
     }
  | e=Tm { e }


tmFormula:
  | e1=tmFormula DISJUNCTION e2=tmFormula
      { mk_term (Op("\\/", [e1;e2])) (rhs2 parseState 1 3) Formula }
  | e1=tmFormula CONJUNCTION e2=tmFormula
      { mk_term (Op("/\\", [e1;e2])) (rhs2 parseState 1 3) Formula }
  | el=separated_nonempty_list(COMMA, tmEq)
      {
        match el with
          | [x] -> x
          | components -> mkTuple components (rhs2 parseState 1 1)
      }


tmEq:
  | e1=tmEq BACKTICK id=lid BACKTICK e2=tmEq
      { mkApp (mk_term (Var id) (rhs2 parseState 2 4) Un) [ e1, Nothing; e2, Nothing ] (rhs2 parseState 1 5) }
  | e1=tmEq op=OPINFIX0a e2=tmEq
      { mk_term (Op(op, [e1; e2])) (rhs2 parseState 1 3) Un}
  | e1=tmEq op=OPINFIX0b e2=tmEq
      { mk_term (Op(op, [e1; e2])) (rhs2 parseState 1 3) Un}
  | e1=tmEq op=OPINFIX0c e2=tmEq
      { mk_term (Op(op, [e1; e2])) (rhs2 parseState 1 3) Un}
  | e1=tmEq EQUALS e2=tmEq
      { mk_term (Op("=", [e1; e2])) (rhs2 parseState 1 3) Un}
  | e1=tmEq COLON_EQUALS e2=tmEq
      { mk_term (Op(":=", [e1; e2])) (rhs2 parseState 1 3) Un}
  | e1=tmEq op=OPINFIX0d e2=tmEq
      { mk_term (Op(op, [e1; e2])) (rhs2 parseState 1 3) Un}
  | e1=tmEq PIPE_RIGHT e2=tmEq
      { mk_term (Op("|>", [e1; e2])) (rhs2 parseState 1 3) Un}
  | e1=tmEq op=OPINFIX1 e2=tmEq
      { mk_term (Op(op, [e1; e2])) (rhs2 parseState 1 3) Un}
  | e1=tmEq op=OPINFIX2 e2=tmEq
      { mk_term (Op(op, [e1; e2])) (rhs2 parseState 1 3) Un}
  | e=tmNoEq
      { e }

tmNoEq:
  | e1=tmNoEq COLON_COLON e2=tmNoEq
      { consTerm (rhs parseState 2) e1 e2 }
  | e1=tmNoEq AMP e2=tmNoEq
      {
        let x, t, f = match extract_named_refinement e1 with
            | Some (x, t, f) -> x, t, f
            | _ -> raise (Error("Missing binder for the first component of a dependent tuple", rhs2 parseState 1 2)) in
        let dom = mkRefinedBinder x t f (rhs2 parseState 1 2) None in
        let tail = e2 in
        let dom, res = match tail.tm with
            | Sum(dom', res) -> dom::dom', res
            | _ -> [dom], tail in
        mk_term (Sum(dom, res)) (rhs2 parseState 1 6) Type
      }
  | e1=tmNoEq MINUS e2=tmNoEq
      { mk_term (Op("-", [e1; e2])) (rhs2 parseState 1 3) Un}
  | e1=tmNoEq op=OPINFIX3 e2=tmNoEq
      { mk_term (Op(op, [e1; e2])) (rhs2 parseState 1 3) Un}
  | e1=tmNoEq op=OPINFIX4 e2=tmNoEq
      { mk_term (Op(op, [e1; e2])) (rhs2 parseState 1 3) Un}
  | MINUS e=tmNoEq
      { mk_uminus e (rhs2 parseState 1 3) Expr }
  | e=refinementTerm
      { e }

refinementTerm:
  | id=ident COLON e=appTerm phi_opt=refineOpt
      {
        let t = match phi_opt with
          | None -> NamedTyp(id, e)
          | Some phi -> Refine(mk_binder (Annotated(id, e)) (rhs2 parseState 1 3) Type None, phi)
        in mk_term t (rhs2 parseState 1 4) Type
      }
  | LBRACE e=recordExp RBRACE { e }
  | e=unaryTerm { e }

refineOpt:
  | phi_opt=option(LBRACE phi=formula RBRACE {phi}) {phi_opt}

%inline formula:
  | e=noSeqTerm { {e with level=Formula} }

recordExp:
  | e_opt=option(e=appTerm WITH {e}) record_fields=separated_trailing_list(SEMICOLON, separated_pair(lid, EQUALS, simpleTerm))
      { mk_term (Record (e_opt, record_fields)) (rhs2 parseState 1 2) Expr }

unaryTerm:
  | op=TILDE e=atomicTerm
      { mk_term (Op(op, [e])) (rhs2 parseState 1 3) Formula }
  | e=appTerm { e }

appTerm:
  | head=indexingTerm args=list(pair(maybeHash, indexingTerm))
      { mkApp head (map (fun (x,y) -> (y,x)) args) (rhs2 parseState 1 2) }

%inline maybeHash:
  |      { Nothing }
  | HASH { Hash }

indexingTerm:
  | e1=atomicTerm DOT_LPAREN e2=term RPAREN
      { mk_term (Op(".()", [ e1; e2 ])) (rhs2 parseState 1 3) Expr }
  | e1=atomicTerm DOT_LBRACK e2=term RBRACK
      { mk_term (Op(".[]", [ e1; e2 ])) (rhs2 parseState 1 3) Expr }
  | e=atomicTerm
      { e }

atomicTerm:
  | UNDERSCORE { mk_term Wild (rhs parseState 1) Un }
  | ASSERT   { mk_term (Var assert_lid) (rhs parseState 1) Expr }
  | tv=tvar     { mk_term (Tvar tv) (rhs parseState 1) Type }
  | c=constant { mk_term (Const c) (rhs parseState 1) Expr }
  | L_TRUE   { mk_term (Name (lid_of_path ["True"] (rhs parseState 1))) (rhs parseState 1) Type }
  | L_FALSE   { mk_term (Name (lid_of_path ["False"] (rhs parseState 1))) (rhs parseState 1) Type }
  | op=OPPREFIX e=atomicTerm
      { mk_term (Op(op, [e])) (rhs2 parseState 1 3) Expr }
  | LPAREN op=operatorTm RPAREN
      { mk_term (Op(op, [])) (rhs2 parseState 1 3) Un }
  (* TODO (KM) : there seems to be a discrepancy here with dependent sums types which need to have at least 2 components *)
  | LENS_PAREN_LEFT el=separated_nonempty_list(COMMA, tmEq) LENS_PAREN_RIGHT
      {
        match el with
          | [x] -> x
          | components -> mkDTuple components (rhs2 parseState 1 1)
      }
  (* TODO : field should have the possibility to be qualified by a module path when projecting *)
  | e=projectionLHS field_projs=list(DOT id=lid {id})
      { fold_left (fun e lid -> mk_term (Project(e, lid)) (rhs2 parseState 1 2) Expr ) e field_projs }
  | BEGIN e=term END
      { e }

%inline operatorTm:
  | op=OPPREFIX
  | op=OPINFIX0a
  | op=OPINFIX0b
  | op=OPINFIX0c
  | op=OPINFIX0d
  | op=OPINFIX1
  | op=OPINFIX2
  | op=OPINFIX3
  | op=OPINFIX4
     { op }


projectionLHS:
  | id=eitherQname targs_opt=option(TYP_APP_LESS targs=separated_nonempty_list(COMMA, atomicTerm) TYP_APP_GREATER {targs})
      {
        let t = if is_name id then Name id else Var id in
        let e = mk_term t (rhs parseState 1) Un in
        match targs_opt with
        | None -> e
        | Some targs -> mkFsTypApp e targs (rhs2 parseState 1 4)
      }
  | LPAREN e=term sort_opt=option(pair(hasSort, simpleTerm)) RPAREN
      {
        let e1 = match sort_opt with
          | None -> e
          | Some (level, t) -> mk_term (Ascribed(e,{t with level=level})) (rhs2 parseState 1 4) level
        in mk_term (Paren e1) (rhs2 parseState 1 4) (e.level)
      }
  | LBRACK_BAR es=semiColonTermList BAR_RBRACK
      {
        let l = mkConsList (rhs2 parseState 1 3) es in
        let pos = (rhs2 parseState 1 3) in
        mkExplicitApp (mk_term (Var (array_mk_array_lid)) pos Expr) [l] pos
      }
  | LBRACK es=semiColonTermList RBRACK
      { mkConsList (rhs2 parseState 1 3) es }
  | PERCENT_LBRACK es=semiColonTermList RBRACK
      { mkLexList (rhs2 parseState 1 3) es }
  | BANG_LBRACE es=separated_list(COMMA, noSeqTerm) RBRACE
      { mkRefSet (rhs2 parseState 1 3) es }

hasSort:
  | SUBTYPE { Expr }
  | SUBKIND { Type }

%inline semiColonTermList:
  | l=separated_trailing_list(SEMICOLON, noSeqTerm) { l }


constant:
  | LPAREN_RPAREN { Const_unit }
  | n=INT
     {
        if snd n then
          errorR(Error("This number is outside the allowable range for representable integer constants", lhs(parseState)));
        Const_int (fst n, None)
     }
  | c=CHAR { Const_char c }
  | s=STRING { Const_string (s,lhs(parseState)) }
  | bs=BYTEARRAY { Const_bytearray (bs,lhs(parseState)) }
  | TRUE { Const_bool true }
  | FALSE { Const_bool false }
  | f=IEEE64 { Const_float f }
  | n=UINT8 { Const_int (n, Some (Unsigned, Int8)) }
  | n=INT8
      {
        if snd n then
          errorR(Error("This number is outside the allowable range for 8-bit signed integers", lhs(parseState)));
        Const_int (fst n, Some (Signed, Int8))
      }
  | n=UINT16 { Const_int (n, Some (Unsigned, Int16)) }
  | n=INT16
      {
        if snd n then
          errorR(Error("This number is outside the allowable range for 16-bit signed integers", lhs(parseState)));
        Const_int (fst n, Some (Signed, Int16))
      }
  | n=UINT32 { Const_int (n, Some (Unsigned, Int32)) }
  | n=INT32
      {
        if snd n then
          errorR(Error("This number is outside the allowable range for 32-bit signed integers", lhs(parseState)));
        Const_int (fst n, Some (Signed, Int32))
      }
  | n=UINT64 { Const_int (n, Some (Unsigned, Int64)) }
  | n=INT64
      {
        if snd n then
          errorR(Error("This number is outside the allowable range for 64-bit signed integers", lhs(parseState)));
        Const_int (fst n, Some (Signed, Int64))
      }
  | REIFY   { Const_reify }

/******************************************************************************/
/*                       Miscaelnous, tools                                   */
/******************************************************************************/

%inline string:
  | s=STRING { string_of_bytes s }

separated_trailing_list(SEP,X):
  | { [] }
  | l=separated_nonempty_list(SEP, X) SEP? { l }
