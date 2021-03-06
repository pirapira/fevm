(*===========================================================================
  Basic representation of n-bit words

  We use n.-tuples of bools, as this gives decidable equality and finiteness
  for free.

  Tuples are practical for evaluation inside Coq, and so all operations on
  words can be evaluated using compute, cbv, etc.

  Proofs of various properties of bitvectors can be found in bitsprops.v
  Definitions of operations on bitvectors can be found in bitsops.v
  Proofs of properties of operations can be found in bitsopsprops.v
  ===========================================================================*)

From Coq Require Import ZArith.ZArith Strings.String.

Require Import mathcomp.ssreflect.ssreflect.
From mathcomp Require Import ssrfun ssrbool eqtype ssrnat seq fintype tuple zmodp.

(* We represent n-bit words by a tuple of booleans. 
 LSB is the leftmost bit or the head of the tuple.
 For example number 9 as an EVMWORD is the tuple:
 1001 0000 ... 0000 - 32 bytes *)

Definition BITS n := n.-tuple bool.

(** We define aliases for various numbers, to speed up proofs.  We use
 [.+1] to ensure convertibility after adding or subtracting 1. *)

Definition n3 := 3.
Definition n7 := 7.
Definition n15 := 15.
Definition n31 := 31.
Definition n63 := 63.
Definition n127 := 127.
Definition n159 := 159.
Definition n255 := 255.

Arguments n3 : simpl never.
Arguments n7 : simpl never.
Arguments n15 : simpl never.
Arguments n31 : simpl never.
Arguments n63 : simpl never.
Arguments n127 : simpl never.
Arguments n159 : simpl never.
Arguments n255 : simpl never.
Opaque n3 n7 n15 n31 n63 n127 n159 n255.

Notation n4 := n3.+1.
Notation n8 := n7.+1.
Notation n16 := n15.+1.
Notation n32 := n31.+1.
Notation n64 := n63.+1.
Notation n128 := n127.+1.
Notation n160 := n159.+1.
Notation n256 := n255.+1.

Definition n24 := 24.
Arguments n24 : simpl never.
Opaque n24.
Definition NIBBLE := BITS n4.

(* Range of word sizes that we support for the stack, memory, and storage *)
Inductive OpSize := 
 OpSize1 (* 8-bits *)
|OpSize2
|OpSize4
|OpSize8
|OpSize16
|OpSize20
|OpSize32.

(* OpSize to nat *)
Definition opSizeToNat (s : OpSize) : nat := 
match s with
|OpSize1 => 1
|OpSize2 => 2
|OpSize4 => 4
|OpSize8 => 8
|OpSize16 => 16
|OpSize20 => 20
|OpSize32 => 32
end.

Definition VWORD s :=
BITS 
(match s with 
 OpSize1 => n8
|OpSize2 => n16
|OpSize4 => n32
|OpSize8 => n64
|OpSize16 => n128
|OpSize20 => n160
|OpSize32 => n256 end).

Definition BYTE := (VWORD OpSize1).

Definition WORD := (VWORD OpSize2).

Definition DWORD := (VWORD OpSize4).

Definition QWORD := (VWORD OpSize8).

Definition DQWORD := (VWORD OpSize16).

Definition ADDRESS := (VWORD OpSize20).

Definition EVMWORD := (VWORD OpSize32).

Identity Coercion VWORDtoBITS : VWORD >-> BITS.
Identity Coercion BYTEtoVWORD : BYTE >-> VWORD.
Identity Coercion WORDtoVWORD : WORD >-> VWORD.
Identity Coercion DWORDtoVWORD : DWORD >-> VWORD.
Identity Coercion QWORDtoVWORD : QWORD >-> VWORD.
Identity Coercion DQWORDtoVWORD : DQWORD >-> VWORD.
Identity Coercion ADDRESStoVWORD : ADDRESS >-> VWORD.
Identity Coercion EVMWORDtoVWORD : EVMWORD >-> VWORD.

(*-----------------------------------------------------------------------
 Constructors
 -----------------------------------------------------------------------*)
Notation "'nilB'" := (nil_tuple _).

(* Concate 1 bit as LSB one *)
Definition consB {n} (b : bool) (p : BITS n) : BITS n.+1 :=
  cons_tuple b p.

Definition joinlsb {n} (pair : BITS n * bool) : BITS n.+1 :=
  cons_tuple pair.2 pair.1.
  
(*------------------------------------------------------------------------
  Destructors
 ------------------------------------------------------------------------*)
Definition splitlsb {n} (p : BITS n.+1) : BITS n * bool :=
  (behead_tuple p, thead p).

Definition droplsb {n} (p : BITS n.+1) : BITS n := 
  (splitlsb p).1.

(*------------------------------------------------------------------------
 Conversion to and from nat numbers.
 ------------------------------------------------------------------------*)
Fixpoint fromNat {n} m : BITS n :=
  if n is _.+1 then
    joinlsb (fromNat m./2, odd m)
  else nilB.

Notation "# m" := (fromNat m) (at level 0).

Arguments fromNat n m : simpl never.

Definition toNat {n} (p : BITS n) :=
  foldr (fun (b : bool) n => b + n.*2) 0 p.

Coercion natAsEVMWORD := @fromNat _ : nat -> EVMWORD.
Coercion natAsADDRESS := @fromNat _ : nat -> ADDRESS.
Coercion natAsDQWORD := @fromNat _ : nat -> DQWORD.
Coercion natAsQWORD := @fromNat _ : nat -> QWORD.
Coercion natAsDWORD := @fromNat _ : nat -> DWORD.
Coercion natAsWORD := @fromNat _ : nat -> WORD.
Coercion natAsBYTE := @fromNat _ : nat -> BYTE.

(* All bits identical *)
Definition copy n b : BITS n :=
  nseq_tuple n b.

Definition zero n := copy n false.

Definition ones n := copy n true.

(*---------------------------------------------------------------------------
 Concatenation and splitting of bit strings
 --------------------------------------------------------------------------*)

(* Most and least significant bits, defaulting to 0 *)
Definition msb {n} (b: BITS n) := last false b.
Definition lsb {n} (b: BITS n) := head false b.

(* p2 is least-significant part *)
Definition catB {n1 n2} (p1: BITS n1) (p2: BITS n2) : BITS (n2+n1) :=
  cat_tuple p2 p1.
Notation "y ## x" := (catB y x) (right associativity, at level 60).

(* The n high bits *)
Fixpoint high n {n2} : BITS (n2+n) -> BITS n :=
  if n2 is _.+1 then fun p => let (p,b) := splitlsb p in high _ p else fun p => p.

(* The n low bits *)
Fixpoint low {n1} n : BITS (n+n1) -> BITS n :=
  if n is _.+1 then
    fun p => let (p,b) := splitlsb p in joinlsb (low _ p, b)
  else fun p => nilB.

(* n1 high and n2 low bits *)
Definition split2 n1 n2 p := (high n1 p, low n2 p).

Definition split3 n1 n2 n3 (p: BITS (n3+n2+n1)) : BITS n1 * BITS n2 * BITS n3 :=
  let (hi,lo) := split2 n1 _ p in
  let (lohi,lolo) := split2 n2 _ lo in (hi,lohi,lolo).

Definition split4 n1 n2 n3 n4 (p: BITS (n4+n3+n2+n1)): BITS n1 * BITS n2 * BITS n3 * BITS n4 :=
  let (b1,rest) := split2 n1 _ p in
  let (b2,rest) := split2 n2 _ rest in
  let (b3,b4)   := split2 n3 _ rest in (b1,b2,b3,b4).

Definition split8 n1 n2 n3 n4 n5 n6 n7 n8 (p: BITS (n8+n7+n6+n5+n4+n3+n2+n1)): BITS n1 * BITS n2 * BITS n3 * BITS n4 * BITS n5 * BITS n6 * BITS n7 * BITS n8 :=
  let '(b1,b2,b3,rest) := split4 n1 n2 n3 _ p in
  let '(b4,b5,b6,rest) := split4 n4 n5 n6 _ rest in
  let '(b7,b8) := split2 n7 n8 rest in (b1,b2,b3,b4,b5,b6,b7,b8).

Definition split16 n1 n2 n3 n4 n5 n6 n7 n8 n9 n10 n11 n12 n13 n14 n15 n16 (p: BITS (n16+n15+n14+n13+n12+n11+n10+n9+n8+n7+n6+n5+n4+n3+n2+n1)): 
BITS n1 * BITS n2 * BITS n3 * BITS n4 * BITS n5 * BITS n6 * BITS n7 * BITS n8 * BITS n9 * BITS n10 * BITS n11 * BITS n12 * BITS n13 * BITS n14 * BITS n15 * BITS n16 :=
  let '(b1,b2,b3,b4,b5,b6,b7,rest) := split8 n1 n2 n3 n4 n5 n6 n7 _ p in
  let '(b8,b9,b10,b11,b12,b13,b14,rest) := split8 n8 n9 n10 n11 n12 n13 n14 _ rest in
  let '(b15,b16) := split2 n15 n16 rest in (b1,b2,b3,b4,b5,b6,b7,b8,b9,b10,b11,b12,b13,b14,b15,b16).

Definition split20 n1 n2 n3 n4 n5 n6 n7 n8 n9 n10 n11 n12 n13 n14 n15 n16 n17 n18 n19 n20 (p: BITS (n20+n19+n18+n17+n16+n15+n14+n13+n12+n11+n10+n9+n8+n7+n6+n5+n4+n3+n2+n1)): 
BITS n1 * BITS n2 * BITS n3 * BITS n4 * BITS n5 * BITS n6 * BITS n7 * BITS n8 * BITS n9 * BITS n10 * BITS n11 * BITS n12 * BITS n13 * BITS n14 * BITS n15 * BITS n16 * BITS n17 * BITS n18 * BITS n19 * BITS n20 :=
  let '(b1,b2,b3,b4,b5,b6,b7,b8,b9,b10,b11,b12,b13,b14,b15,rest) := split16 n1 n2 n3 n4 n5 n6 n7 n8 n9 n10 n11 n12 n13 n14 n15 _ p in
  let '(b16,b17,b18,rest) := split4 n16 n17 n18 _ rest in
  let '(b19,b20) := split2 n19 n20 rest in (b1,b2,b3,b4,b5,b6,b7,b8,b9,b10,b11,b12,b13,b14,b15,b16,b17,b18,b19,b20).

Definition split32 n1 n2 n3 n4 n5 n6 n7 n8 n9 n10 n11 n12 n13 n14 n15 n16 n17 n18 n19 n20 n21 n22 n23 n24 n25 n26 n27 n28 n29 n30 n31 n32 
(p: BITS (n32+n31+n30+n29+n28+n27+n26+n25+n24+n23+n22+n21+n20+n19+n18+n17+n16+n15+n14+n13+n12+n11+n10+n9+n8+n7+n6+n5+n4+n3+n2+n1)): 
BITS n1 * BITS n2 * BITS n3 * BITS n4 * BITS n5 * BITS n6 * BITS n7 * BITS n8 * BITS n9 * BITS n10 * BITS n11 * BITS n12 * BITS n13 * BITS n14 * BITS n15 * BITS n16 * BITS n17 * BITS n18 * BITS n19 * BITS n20 * 
BITS n21 * BITS n22 * BITS n23 * BITS n24 * BITS n25 * BITS n26 * BITS n27 * BITS n28 * BITS n29 * BITS n30 * BITS n31 * BITS n32 :=
  let '(b1,b2,b3,b4,b5,b6,b7,b8,b9,b10,b11,b12,b13,b14,b15,rest) := split16 n1 n2 n3 n4 n5 n6 n7 n8 n9 n10 n11 n12 n13 n14 n15 _ p in
  let '(b16,b17,b18,b19,b20,b21,b22,b23,b24,b25,b26,b27,b28,b29,b30,rest) := split16 n16 n17 n18 n19 n20 n21 n22 n23 n24 n25 n26 n27 n28 n29 n30 _ rest in
  let '(b31,b32) := split2 n31 n32 rest in (b1,b2,b3,b4,b5,b6,b7,b8,b9,b10,b11,b12,b13,b14,b15,b16,b17,b18,b19,b20,b21,b22,b23,b24,b25,b26,b27,b28,b29,b30,b31,b32).

(* Sign extend by {extra} bits *)
Definition signExtend extra {n} (p: BITS n.+1) := copy extra (msb p) ## p.

(* Truncate a signed integer by {extra} bits; return None if this would overflow *)
Definition signTruncate extra {n} (p: BITS (n.+1 + extra)) : option (BITS n.+1) :=
  let (hi,lo) := split2 extra _ p in
  if msb lo && (hi == ones _) || negb (msb lo) && (hi == zero _) then
    Some lo
  else None.

(* Zero extend by {extra} bits *)
Definition zeroExtend extra {n} (p : BITS n) := zero extra ## p.

Coercion BYTEtoDWORD := zeroExtend (n:=8) 24 : BYTE -> DWORD.
Coercion WORDtoDWORD := zeroExtend (n:=16) 16 : WORD -> DWORD.

Coercion BYTEtoEVMWORD := zeroExtend (n:=8) 248 : BYTE -> EVMWORD.
Coercion WORDtoEVMWORD := zeroExtend (n:=16) 240 : WORD -> EVMWORD.
Coercion DWORDtoEVMWORD := zeroExtend (n:=32) 224 : DWORD -> EVMWORD.
Coercion QWORDtoEVMWORD := zeroExtend (n:=64) 192 : QWORD -> EVMWORD.
Coercion DQWORDtoEVMWORD := zeroExtend (n:=128) 128 : DQWORD -> EVMWORD.
Coercion ADDRESStoEVMWORD := zeroExtend (n:=160) 96 : ADDRESS -> EVMWORD.

(* Take m least significant bits of n-bit argument and fill with zeros if m>n *)
Fixpoint lowWithZeroExtend m {n} : BITS n -> BITS m :=
  if n is _.+1 then
    fun p => let (p,b) := splitlsb p in
             if m is m'.+1 then joinlsb (@lowWithZeroExtend m' _ p, b)
             else zero 0
  else fun p => zero m.

(* BITS n to EVMWORD and fill with zeros if n < 256 *)
Definition lowWithZeroExtendToEVMWORD {n} (p : BITS n) : EVMWORD :=
  lowWithZeroExtend 256 p.

(* BITS n to BYTE and fill with zeros if n < 8 *)
Definition lowWithZeroExtendToBYTE {n} (p : BITS n) : BYTE :=
  lowWithZeroExtend 8 p.

(* Truncate an unsigned integer by {extra} bits; return None if this would overflow *)
Definition zeroTruncate extra {n} (p: BITS (n + extra)) : option (BITS n) :=
  let (hi,lo) := split2 extra _ p in
  if hi == zero _ then Some lo else None.

(* Special case: split at the most significant bit.
   split 1 n doesn't work because it requires BITS (n+1) not BITS n.+1 *)
Fixpoint splitmsb {n} : BITS n.+1 -> bool * BITS n :=
  if n is _.+1
  then fun p => let (p,b) := splitlsb p in let (c,r) := splitmsb p in (c,joinlsb(r,b))
  else fun p => let (p,b) := splitlsb p in (b,p).
Definition dropmsb {n} (p: BITS n.+1) := (splitmsb p).2.

(* Extend by one bit at the most significant bit. Again, signExtend 1 n does not work
   because BITS (n+1) is not definitionally equal to BITS n.+1  *)
Fixpoint joinmsb {n} : bool * BITS n -> BITS n.+1 :=
  if n is _.+1
  then fun p => let (hibit, p) := p in
                let (p,b) := splitlsb p in joinlsb (joinmsb (hibit, p), b)
  else fun p => joinlsb (nilB, p.1).
Definition joinmsb0 {n} (p: BITS n) : BITS n.+1 := joinmsb (false,p).

Fixpoint zeroExtendAux extra {n} (p: BITS n) : BITS (extra+n) :=
  if extra is e.+1 then joinmsb0 (zeroExtendAux e p) else p.

Definition joinNibble {n}  (p:NIBBLE) (q: BITS n) : BITS (n.+4) :=
  let (p1,b0) := splitlsb p in
  let (p2,b1) := splitlsb p1 in
  let (p3,b2) := splitlsb p2 in
  let (p4,b3) := splitlsb p3 in
   joinmsb (b3, joinmsb (b2, joinmsb (b1, joinmsb (b0, q)))).

Notation "y ## x" := (catB y x) (right associativity, at level 60).

(* Slice of bits *)
Definition slice n n1 n2 (p: BITS (n+n1+n2)) : BITS n1 :=
  let: (a,b,c) := split3 n2 n1 n p in b. 

Definition updateSlice n n1 n2 (p: BITS (n+n1+n2)) (m:BITS n1) : BITS (n+n1+n2) :=
  let: (a,b,c) := split3 n2 n1 n p in a ## m ## c.

(* Join BYTE to BITS n *)
Definition joinBYTE {n} (pair : BITS n * BYTE) : BITS (n8+n) :=
  cat_tuple pair.2 pair.1.

(* From tuple of BYTEs to BITS n, preserve the order in b *)
Fixpoint fromBytes (b : seq BYTE) : BITS (size b * 8) :=
  match b with
    | nil => #0
    | h::t => joinBYTE ((fromBytes t), h)
  end.

(*---------------------------------------------------------------------------
    Single bit operations
 ---------------------------------------------------------------------------*)

(* Booleans are implicitly coerced to one-bit words, useful in combination with ## *)
Coercion singleBit b : BITS 1 := joinlsb (nilB, b).

(* Get bit i, counting 0 as least significant *)
(* For some reason tnth is not efficiently computable, so we use nth *)
Definition getBit {n} (p: BITS n) (i:nat) := nth false p i.

(* Set bit i to b *)
Fixpoint setBitAux {n} i b : BITS n -> BITS n :=
  if n is _.+1
  then fun p => let (p,oldb) := splitlsb p in
                if i is i'.+1 then joinlsb (setBitAux i' b p, oldb) else joinlsb (p,b)
  else fun p => nilB.

Definition setBit {n} (p: BITS n) i b := setBitAux i b p.

(*---------------------------------------------------------------------------
    Efficient conversion to and from Z
 ---------------------------------------------------------------------------*)

Definition toPosZ {n} (p: BITS n) :=
  foldr (fun b z => if b then Zsucc (Zdouble z) else Zdouble z) Z0 p.

Definition toNegZ {n} (p: BITS n) :=
  foldr (fun b z => if b then Zdouble z else Zsucc (Zdouble z)) Z0 p.

Definition toZ {n} (bs: BITS n.+1) :=
  match splitmsb bs with
  | (false, bs') => toPosZ bs'
  | (true, bs') => Zopp (Zsucc (toNegZ bs'))
  end.

Fixpoint fromPosZ {n} (z: Z): BITS n :=
  if n is _.+1
  then joinlsb (fromPosZ (Zdiv2 z), negb (Zeven_bool z))
  else nilB.

Fixpoint fromNegZ {n} (z: Z): BITS n :=
  if n is _.+1
  then joinlsb (fromNegZ (Zdiv2 z), Zeven_bool z)
  else nilB.

Definition fromZ {n} (z:Z) : BITS n :=
  match z with
  | Zpos _ => fromPosZ z
  | Zneg _ => fromNegZ (Zpred (Zopp z))
  | _ => zero _
  end.

(*---------------------------------------------------------------------------
    Conversion to and from 'Z_(2^n)
 ---------------------------------------------------------------------------*)

Definition toZp {n} (p: BITS n) : 'Z_(2^n) := inZp (toNat p).
Definition fromZp {n} (z: 'Z_(2^n)) : BITS n := fromNat z.

Definition bool_inZp m (b:bool): 'Z_m := inZp b.
Definition toZpAux {m n} (p:BITS n) : 'Z_(2^m) := inZp (toNat p).


(*---------------------------------------------------------------------------
    Support for hexadecimal notation
 ---------------------------------------------------------------------------*)
Section HexStrings.
Import Ascii.

Definition charToNibble c : NIBBLE :=
  fromNat (findex 0 (String c EmptyString) "0123456789ABCDEF0123456789abcdef").
Definition charToBit c : bool := ascii_dec c "1".

(*---------------------------------------------------------------------------
 from Binary string to BITS n 
 ---------------------------------------------------------------------------*)
Fixpoint fromBin s : BITS (length s) :=
  if s is String c s
  then joinmsb (charToBit c, fromBin s) else #0.


(*--------------------------------------------------------------------------
 from Hex string to BITS n
 --------------------------------------------------------------------------*)
Fixpoint fromHex s : BITS (length s * 4) :=
  if s is String c s
  then joinNibble (charToNibble c) (fromHex s) else #0.

(*--------------------------------------------------------------------------
 from character string to BITS n
 --------------------------------------------------------------------------*)
Fixpoint fromString s : BITS (length s * 8) :=
  if s is String c s return BITS (length s * 8)
  then fromString s ## fromNat (n:=8) (nat_of_ascii c) else nilB.

(*-------------------------------------------------------------------------*)
Definition nibbleToChar (n: NIBBLE) :=
  match String.get (toNat n) "0123456789ABCDEF" with None => " "%char | Some c => c end.

(*-------------------------------------------------------------------------*)
Definition appendNibbleOnString n s :=
  (s ++ String.String (nibbleToChar n) EmptyString)%string.

End HexStrings.

(*--------------------------------------------------------------------------
 from BITS n to Hex string
 --------------------------------------------------------------------------*)
Fixpoint toHex {n} :=
  match n return BITS n -> string with
  | 0 => fun bs => EmptyString
  | 1 => fun bs => appendNibbleOnString (zero 3 ## bs) EmptyString
  | 2 => fun bs => appendNibbleOnString (zero 2 ## bs) EmptyString
  | 3 => fun bs => appendNibbleOnString (zero 1 ## bs) EmptyString
  | _ => fun bs => let (hi,lo) := split2 _ 4 bs in appendNibbleOnString lo (toHex hi)
  end.


(*----------------------------------------------------------------------------
 from sequences of BYTEs, ADDRESSes, and EVMWORDs to Hex strings.
 ----------------------------------------------------------------------------*)
Import Ascii.

(* Convert an ASCII character (from the standard Coq library) to a BYTE *)
Definition charToBYTE (c: ascii) : BYTE :=
  let (a0,a1,a2,a3,a4,a5,a6,a7) := c in
  [tuple a0;a1;a2;a3;a4;a5;a6;a7].

(* Convert an ASCII string to a tuple of BYTEs... *)
Fixpoint stringToTupleBYTE (s : string) : (length s).-tuple BYTE :=
  if s is String c s then cons_tuple (charToBYTE c) (stringToTupleBYTE s)
  else nil_tuple _.

(* Which is easily coerced to a sequence *)
Definition stringToSeqBYTE (s: string) : seq BYTE :=
  stringToTupleBYTE s.

(* Notation for hex, binary, and character/string *)
Notation "#x y" := (fromHex y) (at level 0).
Notation "#b y" := (fromBin y) (at level 0).
Notation "#c y" := (fromString y : BYTE) (at level 0).

(* BYTEs to Hex with spaces like 01 0A 0C *)
Fixpoint bytesToHexAux_Char (b : seq BYTE) (res : string) :=
  match b with b::bs =>
    bytesToHexAux_Char bs (String.String (nibbleToChar (high (n2:=4) 4 b)) (
             String.String (nibbleToChar (low 4 b)) (
             String.String (" "%char) res)))
  | nil => res end.

Fixpoint bytesToHexAux (b : seq BYTE) (res : string) :=
  match b with
    | b::bs => bytesToHexAux bs ((toHex b) ++ " " ++ res)
    | nil => res
  end.

               
Definition bytesToHex b :=
  bytesToHexAux b ""%string.


(* ADDRESSes to Hex with spaces *)
Fixpoint addressesToHexAux (a : seq ADDRESS) (res : string) :=
  match a with
    | x::xs => addressesToHexAux xs ((toHex x) ++ " " ++ res)
    | nil => res
  end.

Definition addressesToHex a :=
  addressesToHexAux a ""%string.

(* EVMWORDs to Hex with spaces *)
Fixpoint evmwordsToHexAux (evmw : seq EVMWORD) (res : string) :=
  match evmw with
    | x::xs => evmwordsToHexAux xs ((toHex x) ++ " " ++ res)
    | nil => res
  end.

Definition evmwordsToHex evmw :=
  evmwordsToHexAux evmw ""%string.


(*-------------------------------------------------------------------------------
 Unit test.
 -------------------------------------------------------------------------------*)
Example fortytwo  := #42 : BYTE.
Example fortytwo1 := #x"2A".
Example fortytwo2 := #b"00101010".
Example fortytwo3 := #c"*".
Example overflowbyte := #300 : BYTE.
Compute (("Overflow: " ++ toHex overflowbyte)%string).

(* tuple of 5 BYTEs *)
Example bs : 5.-tuple BYTE := [tuple (#5:BYTE); (#4:BYTE); (#3:BYTE); (#2:BYTE); (#1:BYTE)].
Compute (bytesToHex (rev bs)).

Example fbs := fromBytes (rev bs).
Compute (toHex (lowWithZeroExtendToEVMWORD fbs)).
Compute (toHex (lowWithZeroExtendToBYTE fbs)).

(* tuple of 5 ADDRESSes *)
Example adds : 5.-tuple ADDRESS := [tuple (#5:ADDRESS); (#4:ADDRESS); (#3:ADDRESS); (#2:ADDRESS); (#1:ADDRESS)].
Compute (addressesToHex (rev adds)).

(* tuple of 5 EVMWORDs *)
Example ws : 5.-tuple EVMWORD := [tuple (#5:EVMWORD); (#4:EVMWORD); (#3:EVMWORD); (#2:EVMWORD); (#1:EVMWORD)].
Compute (evmwordsToHex (rev ws)).

