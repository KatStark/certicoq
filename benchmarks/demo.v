Require Import Arith.
  
Unset Template Cast Propositions.

From CertiCoq.Plugin Require Import CertiCoq.


Definition demo1 := List.app (List.repeat true 5) (List.repeat false 3).

CertiCoq Compile demo1.

Definition demo2 := (negb, List.hd_error).

CertiCoq Compile demo2.

Require Import CertiCoq.Benchmarks.vs.
Import VeriStar.
Definition is_valid :=
  match main with
  | Valid => true
  | _ => false
  end.

Time CertiCoq Compile is_valid. (* 5 secs ! *)
