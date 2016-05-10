(****)
Add LoadPath "../common" as Common.
Add LoadPath "../L1_MalechaQuoted" as L1.
(****)

Require Import Lists.List.
Require Import Strings.String.
Require Import Strings.Ascii.
Require Import Arith.EqNat.
Require Import Arith.Compare_dec.
Require Import L1.term.
Require Import L1.program.
Require Import L1.wndEval.
Require Import L1.awndEval.
Require Import L1.wcbvEval.

Local Open Scope string_scope.
Local Open Scope bool.
Local Open Scope list.
Set Implicit Arguments.

(**
Require Import Template.Template.
Quote Definition xx :=
  fun (n:list nat) => match n with cons m ms => cons m ms | nil => nil  end.
Print xx.
**)

(** Weak typed normal form: normal form of wndEval:
*** no wndEval steps possible (including no steps in type fields.
*** TRel is not itself a weak typed normal form, but unbound indices
*** may occur under a binder in a weak typed normal form
**)
Section Sec_environ.
Variable p:environ.
  
Inductive WNorm: Term -> Prop :=
| WNPrf: WNorm TProof
| WNLam: forall nm ty bod, WNorm ty -> WNorm (TLambda nm ty bod)
| WNProd: forall nm ty bod, WNorm ty -> WNorm (TProd nm ty bod)
| WNFix: forall ds br, WDNorms ds -> WNorm (TFix ds br)
| WNAx: forall nm, LookupAx nm p -> WNorm (TConst nm)
| WNCase: forall mch n ty brs,
            WNorm mch -> WNorm ty -> WNorms brs -> ~ isCanonical mch ->
            WNorm (TCase n ty mch brs)
| WNConstruct: forall i n, WNorm (TConstruct i n)
| WNInd: forall i, WNorm (TInd i)
| WNSort: forall srt, WNorm (TSort srt)
| WNApp: forall fn t ts,
           WNorm fn -> WNorm t -> WNorms ts ->
           ~ isLambda fn -> ~ isFix fn -> ~ isApp fn ->
           WNorm (TApp fn t ts)
with WNorms: Terms -> Prop :=
| WNtnil: WNorms tnil
| WNtcons: forall t ts, WNorm t -> WNorms ts -> WNorms (tcons t ts)
with WDNorms: Defs -> Prop :=
| WDNtnil: WDNorms dnil
| WDNtcons: forall t ds n s i,
              WNorm t -> WNorm s -> WDNorms ds -> WDNorms (dcons n t s i ds).
Hint Constructors WNorm WNorm WDNorms.
Scheme WNorm_ind' := Induction for WNorm Sort Prop
      with WNorms_ind' := Induction for WNorms Sort Prop
      with WDNorms_ind' := Induction for WDNorms Sort Prop.
Combined Scheme WNormWNorms_ind
         from WNorm_ind', WNorms_ind', WDNorms_ind' .

Ltac rght := solve [right; intros h; inversion_Clear h; contradiction].
Ltac lft := solve [left; constructor; assumption].

(** WNorm is decidable **)
Lemma WNorm_dec:
  (forall t, WNorm t \/ ~ WNorm t) /\
  (forall ts, WNorms ts \/ ~ WNorms ts) /\
  (forall (ds:Defs), WDNorms ds \/ ~ WDNorms ds).
Proof.
  apply TrmTrmsDefs_ind; intros; auto;
  try (solve[right; intros h; inversion h]);
  try (solve[left; constructor]).
  - destruct H; [lft|rght].
  - destruct H; [lft|rght].
  - destruct (isLambda_dec t). rght.
    destruct (isFix_dec t). rght.
    destruct (isApp_dec t). rght.
    destruct H, H0, H1; try rght.
    + left. apply WNApp; auto.
  - destruct (Lookup_dec s p).
    + destruct H. destruct (isAx_dec x).
      * left. constructor. subst. assumption.
      * right. intros j. inversion j. elim H0.
        unfold LookupAx in H2. apply (Lookup_functional H H2).
    + right. intros h. inversion h. eelim H. apply H1.
  - destruct H, H0, H1; try rght.
    + destruct (isCanonical_dec t0); try rght.
      * left. constructor; auto.
  - destruct H; [lft|rght]. 
  - destruct H, H0; try rght.
    + left. constructor; assumption.
  - destruct H, H0, H1; try rght.
    + left. constructor; assumption.
Qed.

Lemma WNorms_tappendl:
  forall ts us, WNorms (tappend ts us) -> WNorms ts.
Proof.
  induction ts; intros us h.
  - constructor.  - simpl in h. apply WNtcons; inversion_Clear h.
    + assumption.
    + eapply IHts. eassumption.
Qed.


Lemma Wcbv_WNorm:
  WFaEnv p ->
  (forall t s, WcbvEval p t s -> WFapp t -> WNorm s) /\
  (forall ts ss, WcbvEvals p ts ss -> WFapps ts -> WNorms ss) /\
  (forall dts dss, WcbvDEvals p dts dss ->  WFappDs dts -> WDNorms dss).
Proof.
  intros hp.
  apply WcbvEvalEvals_ind; simpl; intros; try (solve[constructor]);
  try inversion_Clear H0; intuition.
  - apply H. assert (j:= Lookup_pres_WFapp hp l). inversion j. assumption.
  - inversion_Clear H2. apply H1. 
    assert (j:= proj1 (wcbvEval_pres_WFapp hp) _ _ w H7). inversion_Clear j.
    apply whBetaStep_pres_WFapp; try assumption.
    eapply (proj1 (wcbvEval_pres_WFapp hp)); eassumption.
  - inversion_Clear H1. apply H0. apply instantiate_pres_WFapp.
    + assumption.
    + refine (proj1 (wcbvEval_pres_WFapp hp) _ _ _ _); eassumption.
  - apply H0. inversion_Clear H1.
    refine (whFixStep_pres_WFapp _ _ _). 
    + assert (j:= proj1 (wcbvEval_pres_WFapp hp) _ _ w H6).
      inversion j. assumption.
    + constructor; intuition.
  - inversion_Clear H2.
    constructor; intuition; unfold isLambda, isFix, isApp in *.
    + destruct H2 as [x1 [x2 [x3 j]]]. discriminate.
    + destruct H2 as [x1 [x2 j]]. discriminate.
    + destruct H2 as [x1 [x2 [x3 j]]]. discriminate.
  - inversion_Clear H2.
    constructor; intuition; unfold isLambda, isFix, isApp in *.
    + destruct H2 as [x1 [x2 [x3 j]]]. discriminate.
    + destruct H2 as [x1 [x2 j]]. discriminate.
    + destruct H2 as [x1 [x2 [x3 j]]]. discriminate.
  - inversion_Clear H2.
    constructor; intuition; unfold isLambda, isFix, isApp in *.
    + destruct H2 as [x1 [x2 [x3 j]]]. discriminate.
    + destruct H2 as [x1 [x2 j]]. discriminate.
    + destruct H2 as [x1 [x2 [x3 j]]]. discriminate.
  - inversion_Clear H1. apply H0. refine (whCaseStep_pres_WFapp _ _ _ e).
    + assumption.
    + constructor.
  - inversion_Clear H1. apply H0. refine (whCaseStep_pres_WFapp _ _ _ e0).
    + assumption.
    + refine (tskipn_pres_WFapp _ _ e).
      assert (j:= proj1 (wcbvEval_pres_WFapp hp) _ _ w H5). inversion_Clear j.
      constructor; assumption.
  - inversion_Clear H2. constructor; try (solve[intuition]).
    intros h. inversion h.
  - inversion_Clear H1. constructor; intuition.
  - inversion_Clear H2. constructor; intuition.
Qed.

Lemma wcbvEval_no_further:
    (forall t s, WcbvEval p t s -> WcbvEval p s s) /\
    (forall ts ss, WcbvEvals p ts ss -> WcbvEvals p ss ss) /\
    (forall ds es, WcbvDEvals p ds es -> WcbvDEvals p es es).
Proof.
  apply WcbvEvalEvals_ind; simpl; intros; auto.
Qed.


(** If a program is in weak normal form, it has no wndEval step **)
Lemma wNorm_no_wndStep_lem:
  (forall t s, wndEval p t s -> ~ WNorm t) /\
  (forall ts ss, wndEvals p ts ss -> ~ WNorms ts) /\
  (forall ds es, wndDEvals p ds es -> ~ WDNorms ds).
Proof.
  apply wndEvalEvals_ind; intros; intros h;
  try (solve[inversion h]);
  try (solve[inversion h; subst; contradiction]).
  - inversion h.
    inversion l; subst;
    unfold LookupDfn in l; unfold LookupAx in H0;
    assert (j:= Lookup_functional l H0); discriminate.
  - inversion h. subst. elim H5. exists nm, ty, bod. reflexivity.
  - inversion h. subst. elim H6. constructor.
  - inversion h. subst. elim H6. constructor.
  - inversion h. subst. elim H6. exists dts, m. reflexivity.
  - destruct t; simpl in h; inversion h; try (contradiction).
    + subst. elim H. constructor; try assumption.
      apply (WNorms_tappendl _ _ H5).
Qed.

Lemma wNorm_no_wndStep:
  forall t, WNorm t -> no_wnd_step p t.
unfold no_wnd_step, no_wnds_step, no_step. intros t h0 b h1.
elim (proj1 (wNorm_no_wndStep_lem) _ _ h1). assumption.
Qed.

End Sec_environ.

(****
Lemma no_wndStep_wNorm:
  (forall p n t, Crct p n t -> n = 0 -> no_wnd_step p t -> WNorm t) /\
  (forall p n ts, Crcts p n ts -> n = 0 ->
                  no_wnds_step p ts -> WNorms ts) /\
  (forall (p:environ) (n:nat) (ds:Defs), CrctDs p n ds -> True).
apply (CrctCrctsCrctDs_ind); intros; try auto; try (solve [constructor]).
- apply H0. assumption. intros sx h. elim (H5 sx). destruct (wndEval_weaken p).
  apply H6; assumption.
- rewrite H2 in H. omega.
- apply WNCast.
  + apply H0. trivial. intros s j. 
    elim (H4 (TCast s ck ty)). apply (sCastTrm _ _ j).
  + apply H2. trivial. intros s j.
    elim (H4 (TCast t ck s)). apply (sCastTy _ _ j).
- apply WNProd. apply H2. trivial. intros s j. elim (H4 (TProd nm s bod)).
  apply sProdTy. trivial.
- apply WNLam. apply H2. trivial. intros s j. elim (H4 (TLambda nm s bod)).
  apply sLamTy. trivial.
- elim (H6 (instantiate dfn 0 bod)). apply sLetIn.
- apply WNApp. apply H0. trivial. intros s j. elim (H6 (TApp s a args)).
  + apply sAppFn. assumption.
  + apply (H2 H5). intros s j. elim (H6 (TApp fn s args)).
    apply sAppArg. assumption.
  + induction args. auto. apply (H4 H5). intros sx j. inversion_clear j.
    * elim (H6 (TApp fn a (tcons r args))). apply sAppArgs. apply saHd. auto.
    * elim (H6 (TApp fn a (tcons t ss))). apply sAppArgs. apply saTl. auto.
  + intros h. destruct h. destruct H7. destruct H7.
    elim (H6 (whBetaStep x1 a args)). rewrite H7. apply sBeta.
  + intros h. destruct h. destruct H7. rewrite H7 in H6.
    unfold no_wnd_step in H6. elim H6. admit.
(**    eelim (H6). rewrite H7. apply sFix. unfold whFixStep. destruct (whFixStep x x0 (tcons a args)). ereflexivity. rewrite H7. apply sFix.
**)
- eelim (H3). apply sConst. eassumption. 
- subst. apply WNCase.
  + apply H0. reflexivity. unfold no_wnd_step. intros s h. eelim H6. 
    eapply wndEvalRTC_Case_mch.

unfold no_wnd_step in H6.
- subst. destruct (isCanonical_dec mch).
  + inversion H5. edestruct H6. rewrite <- H7. apply sCase0. unfold whCaseStep. simpl. [apply sCase0 | apply sCasen].
  + constructor; intuition.
    * apply H7. intros s h. elim (H6 (TCase m ty s brs)). apply sCaseArg. 
      assumption.
    * apply H2. intros s h. elim (H6 (TCase m s mch brs)). apply sCaseTy. 
      assumption.
    * apply H0. intros s h. elim (H6 (TCase m ty mch s)). apply sCaseBrs.
      assumption.
- subst. intuition. constructor.
  + apply H3. intros s h. elim (H4 (tcons s ts)). apply saHd. assumption.
  + apply H0. intros s h. elim (H4 (tcons t s)). apply saTl. assumption.
Qed.
***)