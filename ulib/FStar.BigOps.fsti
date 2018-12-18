(*
   Copyright 2008-2018 Microsoft Research

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
*)
module FStar.BigOps

(* This library provides propositional connectives over finite sets
   expressed as lists, aka "big operators", in analogy with LaTeX
   usage for \bigand, \bigor, etc.

   The library is designed with a dual usage in mind:

     1. Normalization: When applied to a list literal, we want
       `big_and f [a;b;c]` to implicilty reduce to `f a /\ f b /\ f c`

     2. Symbolic manipulation: We provide lemmas of the form

        ```big_and f l <==> forall x. L.memP x l ==> f x```

        In this latter form, partially computing `big_and` as a fold
        over a list is cumbersome for proof. So, we provide variants
        `big_and'` etc., that do not reduce implicitly.
*)
module L = FStar.List.Tot

(* Every term that is to be reduced is marked with this attribute *)
private
let __reduce__ = ()

(* Implicitly reducing terms are defined using applications of `normal` *)
unfold
let normal (#a:Type) (x:a) : a =
  FStar.Pervasives.norm
    [iota;
     zeta;
     delta_only [`%L.fold_right_gtot; `%L.map_gtot];
     delta_attr [`%__reduce__];
     primops;
     simplify]
     x

(* A useful lemma to relate terms to their implicilty reducing variants *)
val normal_eq (#a:Type) (f:a)
  : Lemma (f == normal f)

(* A generalized version of `map` where we map into a type `c` *)
[@__reduce__] private
let map_op' #a #b #c (op:b -> c -> GTot c) (f:a -> GTot b) (l:list a) (z:c)
  : GTot c
  = L.fold_right_gtot #a #c l (fun x acc -> f x `op` acc) z

(* `big_and f l = /\_{x in l} f x` *)
[@__reduce__]
let big_and' #a (f:a -> Type) (l:list a)
  : Type
  = map_op' l_and f l True
[@__reduce__] unfold
let big_and #a (f:a -> Type) (l:list a)
  : Type
  = normal (big_and' f l)

(* `big_or f l = \/_{x in l} f x` *)
[@__reduce__]
let big_or' #a (f:a -> Type) (l:list a)
  : Type
  = map_op' l_or f l False
[@__reduce__] unfold
let big_or #a (f:a -> Type) (l:list a)
  : Type
  = normal (big_or' f l)

[@__reduce__]
private
let rec pairwise_op' #a #b (op:b -> b -> GTot b) (f:a -> a -> b) (l:list a) (z:b)
  : GTot b
  = match l with
    | [] -> z
    | hd::tl -> map_op' op (f hd) tl z `op` pairwise_op' op f tl z

(* `pairwise_and f l` conjoins `f` on all pairs excluding the diagonal
   i.e., `pairwise_and f [a; b; c] = f a b /\ f a c /\ f b c`
*)
[@__reduce__]
let pairwise_and' #a (f:a -> a -> Type) (l:list a)
  : Type
  = pairwise_op' l_and f l True
[@__reduce__] unfold
let pairwise_and #a (f:a -> a -> Type) (l:list a)
  : Type
  = normal (pairwise_and' f l)

(* `pairwise_or f l` disjoins `f` on all pairs excluding the diagonal
   i.e., `pairwise_or f [a; b; c] = f a b \/ f a c \/ f b c`
*)
[@__reduce__]
let pairwise_or' #a (f:a -> a -> Type) (l:list a)
  : Type
  = pairwise_op' l_or f l False
[@__reduce__] unfold
let pairwise_or #a (f:a -> a -> Type) (l:list a)
  : Type
  = normal (pairwise_or' f l)

(*** Lemmas about the operations ***)

(* Equations for `map_op` showing how it folds over the list *)
val map_op'_nil
      (#a:Type) (#b:Type) (#c:Type)
      (op:b -> c -> GTot c) (f:a -> GTot b) (z:c)
  : Lemma (map_op' op f [] z == z)

val map_op'_cons
      (#a:Type) (#b:Type) (#c:Type)
      (op:b -> c -> GTot c) (f:a -> GTot b) (hd:a) (tl:list a) (z:c)
  : Lemma (map_op' op f (hd::tl) z == f hd `op` map_op' op f tl z)

////////////////////////////////////////////////////////////////////////////////
(* Equations for `big_and` showing it to be a fold *)
val big_and_nil (#a:Type) (f:a -> Type)
  : Lemma (big_and f [] == True)

val big_and_cons (#a:Type) (f:a -> Type) (hd:a) (tl:list a)
  : Lemma (big_and f (hd :: tl) == (f hd /\ big_and f tl))

(* `big_and f l` is a `prop`

   Note: defining `big_and` to intrinsically be in `prop`
   is also possible, but it's much more tedious in proofs.

   This is in part because the `/\` is not defined in prop,
   though one can prove that `a /\ b` is a prop.

   The discrepancy means that I preferred to prove these
   operators in `prop` extrinsically.
*)
val big_and_prop (#a:Type) (f:a -> Type) (l:list a)
  : Lemma (big_and f l `subtype_of` unit)

(* Interpreting the finite conjunction `big_and f l`
   as an infinite conjunction `forall` *)
val big_and_forall (#a:Type) (f: a -> Type) (l:list a)
  : Lemma (big_and f l <==> (forall x. L.memP x l ==> f x))

////////////////////////////////////////////////////////////////////////////////
(* Equations for `big_or` showing it to be a fold *)
val big_or_nil (#a:Type) (f:a -> Type)
  : Lemma (big_or f [] == False)

val big_or_cons (#a:Type) (f:a -> Type) (hd:a) (tl:list a)
  : Lemma (big_or f (hd :: tl) == (f hd \/ big_or f tl))

(* `big_or f l` is a `prop`
    See the remark above on the style of proof for prop *)
val big_or_prop (#a:Type) (f:a -> Type) (l:list a)
  : Lemma (big_or f l `subtype_of` unit)

(* Interpreting the finite disjunction `big_or f l`
   as an infinite disjunction `exists` *)
val big_or_exists (#a:Type) (f: a -> Type) (l:list a)
  : Lemma (big_or f l <==> (exists x. L.memP x l /\ f x))

////////////////////////////////////////////////////////////////////////////////
let symmetric (#a:Type) (f: a -> a -> Type) =
  forall x y. f x y <==> f y x

let reflexive (#a:Type) (f: a -> a -> Type) =
  forall x. f x x

let anti_reflexive (#a:Type) (f: a -> a -> Type) =
  forall x. ~(f x x)

////////////////////////////////////////////////////////////////////////////////
(* Equations for `pairwise_and` showing it to be a fold with big_and *)
val pairwise_and_nil (#a:Type) (f:a -> a -> Type0)
  : Lemma (pairwise_and f [] == True)

val pairwise_and_cons (#a:Type) (f:a -> a -> Type0) (hd:a) (tl:list a)
  : Lemma (pairwise_and f (hd::tl) == (big_and (f hd) tl /\ pairwise_and f tl))

(* `pairwise_and f l` is a prop
    See the remark above on the style of proof for prop *)
val pairwise_and_prop (#a:Type) (f:a -> a -> Type) (l:list a)
  : Lemma (pairwise_and f l `subtype_of` unit)

(* `pairwise_and f l` for symmetric relations `f`
    interpreted as universal quantification over
    pairs of list elements, excluding repeats *)
val pairwise_and_forall (#a:Type) (f: a -> a -> Type) (l:list a)
  : Lemma
    (requires symmetric f /\ (L.no_repeats_p l \/ reflexive f))
    (ensures (pairwise_and f l <==> (forall x y. L.memP x l /\ L.memP y l /\ x =!= y ==> f x y)))

////////////////////////////////////////////////////////////////////////////////
(* Equations for `pairwise_or` showing it to be a fold with big_or *)
val pairwise_or_nil (#a:Type) (f:a -> a -> Type0)
  : Lemma (pairwise_or f [] == False)

val pairwise_or_cons (#a:Type) (f:a -> a -> Type0) (hd:a) (tl:list a)
  : Lemma (pairwise_or f (hd::tl) == (big_or (f hd) tl \/ pairwise_or f tl))

(* `pairwise_or f l` is a prop
    See the remark above on the style of proof for prop *)
val pairwise_or_prop (#a:Type) (f:a -> a -> Type) (l:list a)
  : Lemma (pairwise_or f l `subtype_of` unit)

(* `pairwise_or f l` for symmetric relations `f`
    interpreted as existential quantification over
    pairs of list elements, excluding repeats *)
val pairwise_or_exists (#a:Type) (f: a -> a -> Type) (l:list a)
  : Lemma
    (requires symmetric f /\ (L.no_repeats_p l \/ anti_reflexive f))
    (ensures (pairwise_or f l <==> (exists x y. L.memP x l /\ L.memP y l /\ x =!= y /\ f x y)))
