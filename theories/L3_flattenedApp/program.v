Require Import FunInd.
Require Import Coq.Lists.List.
Require Import Coq.Strings.String.
Require Import Coq.Strings.Ascii.
Require Import Coq.Arith.Compare_dec.
Require Import Coq.omega.Omega.
Require Import Common.Common.
Require Import L3.term.
Require Import L3.compile.

Local Open Scope string_scope.
Local Open Scope bool.
Local Open Scope list.
Set Implicit Arguments.


(** Check that a named datatype and constructor exist in the environment **)
Definition defaultCnstr := {| CnstrNm:=""; CnstrArity:= 0 |}.
Definition defaultItyp := {| itypNm:=""; itypCnstrs:=nil |}.
Definition CrctCnstr (ipkg:itypPack) (inum cnum:nat) (args:nat): Prop :=
  match
    (do ity <- getInd ipkg inum;
     do itp <- getCnstr ity cnum;
        ret (CnstrArity itp))
  with
  | Exc s => False
  | Ret n => n = args
  end.

Definition getIndArities pack n :=
  do ity <- getInd pack n;
     ret (List.map CnstrArity ity.(itypCnstrs)).

(****
Fixpoint is_n_lambda (n : nat) (t : Term) : bool :=
  match n with
  | 0%nat => true
  | S n => 
    match t with
    | TLambda _ t => is_n_lambda n t
    | _ => false
    end
  end.

Definition CrctBranches (e: environ Term) (brs: Defs) : Prop :=
  forall i,
    match dnth i brs with
      | Some (mkdef _ _ _ 
      | Some ar, Some t => is_n_lambda ar t = true
      | _, _ => False
    end.
 ***)

Inductive match_annot : list Cnstr -> Brs -> Prop :=
| match_annot_nil : match_annot nil bnil
| match_annot_cons t args c cnstrs ds :
    c.(CnstrArity) = args ->
    match_annot cnstrs ds ->
    match_annot (c :: cnstrs) (bcons args t ds).

Definition crctAnnot (e : environ Term) ann brs :=
  let 'mkInd nm tndx := ann in
  exists pack ityp,
    LookupTyp nm e 0 pack /\
    getInd pack tndx = Ret ityp /\
    match_annot ityp.(itypCnstrs) brs.

(** correctness specification for programs (including local closure) **)
Inductive crctTerm: environ Term -> nat -> Term -> Prop :=
| ctRel: forall p n m, crctEnv p -> m < n -> crctTerm p n (TRel m)
| ctProof: forall p n, crctEnv p -> crctTerm p n TProof
| ctLam: forall p n nm bod,
           crctTerm p (S n) bod -> crctTerm p n (TLambda nm bod)
| ctLetIn: forall p n nm dfn bod,
             crctTerm p n dfn -> crctTerm p (S n) bod ->
             crctTerm p n (TLetIn nm dfn bod)
| ctApp: forall p n fn arg,
           crctTerm p n fn -> crctTerm p n arg ->
           crctTerm p n (TApp fn arg)
| ctConst: forall p n pd nm,
             crctEnv p -> LookupDfn nm p pd -> crctTerm p n (TConst nm)
| ctConstructor: forall p n ipkgNm inum cnum args ipkg itp cstr,
                   LookupTyp ipkgNm p 0 ipkg ->
                   getInd ipkg inum = Ret itp ->
                   getCnstr itp cnum = Ret cstr ->
                   CnstrArity cstr = tlength args ->
                   crctTerms p n args ->
                   crctTerm p n (TConstruct (mkInd ipkgNm inum) cnum args)
| ctCase: forall p n i mch brs,
    crctTerm p n mch -> crctBs p n brs ->
    crctAnnot p i brs ->
    crctTerm p n (TCase i mch brs)
| ctFix: forall p n ds m,
           crctDs p (n + dlength ds) ds -> m < dlength ds ->
           crctTerm p n (TFix ds m)
(* crctEnvs are closed in both ways *)
with crctEnv: environ Term -> Prop :=
| ceNil: crctEnv nil
| ceTrmCons: forall nm s p,
    fresh nm p -> crctTerm p 0 s -> crctEnv ((nm,ecTrm s)::p)
| ceTypCons: forall nm m s p,
    crctEnv p -> fresh nm p -> crctEnv ((nm,AstCommon.ecTyp Term m s)::p)
with crctTerms: environ Term -> nat -> Terms -> Prop :=
| ctsNil: forall p n, crctEnv p -> crctTerms p n tnil
| ctsCons: forall p n t ts,
    crctTerm p n t -> crctTerms p n ts -> crctTerms p n (tcons t ts)
with crctBs: environ Term -> nat -> Brs -> Prop :=
| cbsNil: forall p n, crctEnv p -> crctBs p n bnil
| cbsCons: forall p n m t ts,
    crctTerm p n t -> crctBs p n ts ->  crctBs p n (bcons m t ts)
with crctDs: environ Term -> nat -> Defs -> Prop :=
| cdsNil: forall p n nm bod ix,
    crctEnv p -> crctTerm p n bod -> isLambda bod ->
    crctDs p n (dcons nm bod ix dnil)
| cdsCons: forall p n nm bod ix ds,
    crctTerm p n bod -> isLambda bod -> crctDs p n ds ->
    crctDs p n (dcons nm bod ix ds).
Hint Constructors crctTerm crctTerms crctBs crctDs crctEnv.
Scheme crct_ind' := Minimality for crctTerm Sort Prop
  with crcts_ind' := Minimality for crctTerms Sort Prop
  with crctBs_ind' := Minimality for crctBs Sort Prop
  with crctDs_ind' := Minimality for crctDs Sort Prop
  with crctEnv_ind' := Minimality for crctEnv Sort Prop.
Combined Scheme crctCrctsCrctBsDsEnv_ind from
         crct_ind', crcts_ind', crctBs_ind', crctDs_ind', crctEnv_ind'.

Lemma crctDs_nonNil:
  forall p n ds, crctDs p n ds -> dlength ds > 0.
Proof.
  induction 1; cbn; intuition.
Qed.

Lemma Crct_WFTrm:
  (forall p n t, crctTerm p n t -> WFTrm t n) /\
  (forall p n ts, crctTerms p n ts -> WFTrms ts n) /\
  (forall p n bs, crctBs p n bs -> WFTrmBs bs n) /\
  (forall p n (ds:Defs), crctDs p n ds -> WFTrmDs ds n) /\
  (forall p, crctEnv p -> True).
Proof.
  apply crctCrctsCrctBsDsEnv_ind; intros; auto.
Qed.
  
Lemma Crct_CrctEnv:
  (forall p n t, crctTerm p n t -> crctEnv p) /\
  (forall p n ts, crctTerms p n ts -> crctEnv p) /\
  (forall p n bs, crctBs p n bs -> crctEnv p) /\
  (forall p n (ds:Defs), crctDs p n ds -> crctEnv p) /\
  (forall (p:environ Term), crctEnv p -> True).
Proof.
  apply crctCrctsCrctBsDsEnv_ind; intros; intuition.
Qed.

Lemma Crct_up:
  (forall p n t, crctTerm p n t -> crctTerm p (S n) t) /\
  (forall p n ts, crctTerms p n ts -> crctTerms p (S n) ts) /\
  (forall p n bs, crctBs p n bs -> crctBs p (S n) bs) /\
  (forall p n (ds:Defs), crctDs p n ds -> crctDs p (S n) ds) /\
  (forall p, crctEnv p -> True). 
Proof.
  apply crctCrctsCrctBsDsEnv_ind; intros;
    try (solve [constructor; assumption]).
  - apply ctRel; try assumption. omega.
  - eapply ctConst; eassumption.
  - eapply ctConstructor; try eassumption.
Qed.

Lemma CrctDs_Up:
  forall n p ds, crctDs p n ds -> forall m, n <= m -> crctDs p m ds.
Proof.
  intros n p ds h. induction 1. assumption.
  apply (proj1 (proj2 (proj2 (proj2 Crct_up)))). assumption.
Qed.

Lemma Crct_UP:
  forall n p t, crctTerm p n t -> forall m, n <= m -> crctTerm p m t.
Proof.
  intros n p t h. induction 1. assumption. apply Crct_up. assumption.
Qed.

Lemma Crct_Up:
  forall n p t, crctTerm p 0 t -> crctTerm p n t.
Proof.
  intros. eapply Crct_UP. eassumption. omega.
Qed.
Hint Resolve Crct_Up Crct_UP.

Lemma Crct_fresh_Pocc:
  (forall p n t, crctTerm p n t -> forall nm, fresh nm p -> ~ PoccTrm nm t) /\
  (forall p n ts, crctTerms p n ts ->
                  forall nm, fresh nm p -> ~ PoccTrms nm ts) /\
  (forall p n bs, crctBs p n bs ->
                  forall nm, fresh nm p -> ~ PoccBrs nm bs) /\
  (forall p n (ds:Defs), crctDs p n ds ->
                         forall nm, fresh nm p -> ~ PoccDefs nm ds) /\
  (forall (p:environ Term), crctEnv p -> True).
Proof.
  apply crctCrctsCrctBsDsEnv_ind; intros; auto; intros j; auto;
    inversion_Clear j;
  try (specialize (H2 _ H3); contradiction);
  try (specialize (H2 _ H5); contradiction);
  try (specialize (H5 _ H6); contradiction);
  try (specialize (H0 _ H3); contradiction);
  try (specialize (H0 _ H1); contradiction);
  try (specialize (H0 _ H6); contradiction);
  try (specialize (H0 _ H4); contradiction);
  try (specialize (H1 _ H4); contradiction);
  try (specialize (H1 _ H5); contradiction);
  try (specialize (H3 _ H4); contradiction);
  try (specialize (H3 _ H5); contradiction);
  try (specialize (H3 _ H6); contradiction);
  try (specialize (H4 _ H5); contradiction).
  - unfold LookupDfn in H1. elim (Lookup_fresh_neq H1 H2). reflexivity.
  - unfold LookupTyp in H. destruct H.
    elim (Lookup_fresh_neq H H5). reflexivity.
  - specialize (H2 _ H4). contradiction.
  - destruct H3 as (pack&ityp&Hlook&_).
    unfold LookupTyp in Hlook. destruct Hlook.
    elim (Lookup_fresh_neq H3 H4). reflexivity.
  - specialize (H0 _ H2). contradiction.
  - specialize (H2 _ H4). contradiction.
  - inversion H6. 
Qed.

Lemma Crct_weaken:
  (forall p n t, crctTerm p n t -> 
                 forall nm s, fresh nm p -> crctTerm p 0 s ->
                              crctTerm ((nm,ecTrm s)::p) n t) /\
  (forall p n ts, crctTerms p n ts -> 
                  forall nm s, fresh nm p -> crctTerm p 0 s ->
                               crctTerms ((nm,ecTrm s)::p) n ts) /\
  (forall p n bs, crctBs p n bs -> 
                  forall nm s, fresh nm p -> crctTerm p 0 s ->
                               crctBs ((nm,ecTrm s)::p) n bs) /\
  (forall p n ds, crctDs p n ds -> 
                  forall nm s, fresh nm p -> crctTerm p 0 s ->
                               crctDs ((nm,ecTrm s)::p) n ds) /\
  (forall p, crctEnv p -> True).
Proof.
  apply crctCrctsCrctBsDsEnv_ind; intros;
  try (solve[repeat econstructor; intuition]);
  try (econstructor; intuition); try eassumption.
  - unfold LookupDfn in *. constructor.
    apply neq_sym. apply (Lookup_fresh_neq H1 H2). eassumption.
  - destruct H. unfold LookupTyp. split; try eassumption.
    constructor; try eassumption.
    apply neq_sym. eapply Lookup_fresh_neq; eassumption.
  - red. red in H3. destruct i. destruct H3 as [pack [ityp0 [Hlook [Hget Hann]]]].
    exists pack. exists ityp0. intuition.
    destruct Hlook. split; auto. constructor; auto.
    apply neq_sym. eapply Lookup_fresh_neq; eassumption.
Qed.

Lemma Crct_weaken_Typ:
  (forall p n t, crctTerm p n t -> 
                 forall nm s m, fresh nm p ->
                              crctTerm ((nm,ecTyp Term m s)::p) n t) /\
  (forall p n ts, crctTerms p n ts -> 
                  forall nm s m, fresh nm p ->
                               crctTerms ((nm,ecTyp Term m s)::p) n ts) /\
  (forall p n ts, crctBs p n ts -> 
                  forall nm s m, fresh nm p ->
                               crctBs ((nm,ecTyp Term m s)::p) n ts) /\
  (forall p n ds, crctDs p n ds -> 
                  forall nm s m, fresh nm p ->
                               crctDs ((nm,ecTyp Term m s)::p) n ds) /\
  (forall p, crctEnv p -> True).
Proof.
  apply crctCrctsCrctBsDsEnv_ind; intros;
  try (solve[repeat econstructor; intuition]);
  try (econstructor; intuition); try eassumption.
  - unfold LookupDfn in *. constructor.
    apply neq_sym. apply (Lookup_fresh_neq H1 H2). eassumption.
  - unfold LookupTyp in *. destruct H. split; try eassumption.
    constructor; try eassumption.
    apply neq_sym. apply (Lookup_fresh_neq H). assumption.
  - red. red in H3. destruct i. destruct H3 as [pack [ityp0 [Hlook [Hget Hann]]]].
    exists pack. exists ityp0. intuition.
    destruct Hlook. split; auto. constructor; auto.
    apply neq_sym. eapply Lookup_fresh_neq; eassumption.
Qed.

Lemma Crct_strengthen:
  (forall pp n s, crctTerm pp n s -> forall nm ec p, pp = (nm,ec)::p ->
                 ~ PoccTrm nm s -> crctTerm p n s) /\
  (forall pp n ss, crctTerms pp n ss -> forall nm ec p, pp = (nm,ec)::p ->
                 ~ PoccTrms nm ss -> crctTerms p n ss) /\
  (forall pp n ss, crctBs pp n ss -> forall nm ec p, pp = (nm,ec)::p ->
                 ~ PoccBrs nm ss -> crctBs p n ss) /\
  (forall pp n ds, crctDs pp n ds -> forall nm ec p, pp = (nm,ec)::p ->
                 ~ PoccDefs nm ds -> crctDs p n ds) /\
  (forall (pp:environ Term), crctEnv pp -> crctEnv (List.tl pp)).
Proof.
  apply crctCrctsCrctBsDsEnv_ind; intros; subst;
    try (econstructor; eassumption);
    try (constructor; try eassumption; inversion_Clear H; assumption).
  - constructor. eapply H0. reflexivity. intros h. elim H2.
    constructor. assumption.
   - constructor. eapply H0. reflexivity.
    + intros h. elim H4. apply PoLetInDfn. assumption.
    + eapply H2. reflexivity. intros h. elim H4. eapply PoLetInBod.
      assumption.                                                   
  - constructor; try assumption. eapply H0. reflexivity.
    + intros h. elim H4. eapply PoAppL. assumption.
    + eapply H2. reflexivity. intros h. elim H4. apply PoAppA. assumption.
  - econstructor. exact H0. unfold LookupDfn in *.
    inversion_Clear H1.
    + elim H3. constructor.
    + eassumption.
  - econstructor; try eassumption.
    + unfold LookupTyp in *. split; intuition.
      eapply Lookup_strengthen. eassumption. reflexivity.
      inversion_Clear H5.
      * elim H6. constructor.
      * assumption.
    + eapply H4. reflexivity. intros h. elim H6. apply PoCnstrA.
      assumption.
  - econstructor; try eassumption.
    + eapply H0. reflexivity. intros h. elim H5. constructor. assumption.
    + eapply H2. reflexivity. intros h. elim H5.
      apply PoCaseR. assumption.
    + destruct i. destruct H3 as (pack&ityp&Hlook&Hget&Hann).
      exists pack, ityp. split; auto.
      destruct Hlook as [Hlook Hnil]. split; auto.
      inversion Hlook; subst. elim H5. apply PoCaseAnn. assumption.
  - econstructor; try eassumption. eapply H0. reflexivity. intros h.
    elim H3. constructor. assumption.
  - constructor.
    + eapply H0. reflexivity. intros h. elim H4. constructor. assumption.
    + eapply H2. reflexivity. intros h. elim H4. apply PoTtl. assumption.
  - constructor.
    + eapply H0. reflexivity. intros h. elim H4. constructor. assumption.
    + eapply H2. reflexivity. intros h. elim H4. apply PoBtl. assumption.
  - constructor; try assumption.
    + eapply H2. reflexivity. intros h. elim H5. constructor. assumption.
  - constructor; try assumption.
    + eapply H0. reflexivity. intros h. elim H5. constructor. assumption. 
    + eapply H3. reflexivity. intros h. elim H5. constructor.
      destruct (notPoccDefs H5). contradiction.
  - cbn. eapply (proj1 Crct_CrctEnv). eassumption.
  - cbn. assumption.
Qed.

Lemma TWrong_not_Crct:
  forall p n s, ~ crctTerm p n (TWrong s).
Proof.
  induction p; intros; intros h.
  - inversion h.
  - eelim IHp. destruct a. eapply (proj1 Crct_strengthen _ _ _ h).
    + reflexivity.
    + intros j. inversion j.
Qed.

(** Crct inversions **)

Lemma LookupDfn_pres_Crct:
  forall p, crctEnv p -> forall nm u, LookupDfn nm p u ->
                                      forall m, crctTerm p m u.
Proof.
  induction p; intros; unfold LookupDfn in *.
  - inversion H0.
  - inversion_Clear H0. inversion_Clear H.
    + apply (proj1 Crct_weaken); try assumption. apply Crct_Up. assumption.
    + inversion_Clear H. apply (proj1 Crct_weaken); try assumption.
      * eapply IHp. apply (proj1 Crct_CrctEnv p _ _ H5). eassumption.
      * apply (proj1 Crct_weaken_Typ); try assumption.
        eapply IHp; try eassumption.
Qed.
  
  
Lemma Crct_invrt_Rel:
  forall p n m, crctTerm p n (TRel m) -> m < n.
Proof.
  intros. inversion_Clear H. assumption.
Qed.

Lemma pre_Crct_LookupDfn_Crct:
  (forall p n t, crctTerm p n t ->
                 forall nm t, LookupDfn nm p t -> crctTerm p 0 t) /\
  (forall p n ts, crctTerms p n ts ->
                  forall nm t, LookupDfn nm p t -> crctTerm p 0 t) /\
  (forall p n bs, crctBs p n bs ->
                  forall nm t, LookupDfn nm p t -> crctTerm p 0 t) /\
  (forall p n (ds:Defs), crctDs p n ds ->
                         forall nm t, LookupDfn nm p t -> crctTerm p 0 t) /\
  (forall p, crctEnv p -> forall nm t, LookupDfn nm p t -> crctTerm p 0 t).
Proof.
  apply crctCrctsCrctBsDsEnv_ind; intros; unfold LookupDfn in *;
  try (eapply H0; eassumption); try (eapply H1; eassumption).
  - eapply H4; eassumption.          
  - inversion H.
  - inversion_Clear H2.
    + apply Crct_weaken; assumption.
    + apply Crct_weaken; try assumption. eapply H1. eassumption.
  - inversion_Clear H2.
    + apply Crct_weaken_Typ; try assumption. eapply H0. eassumption.
Qed.


Lemma Crct_invrt_:
  forall (ev:environ Term), crctEnv ev ->
  forall nm s p, ev = (nm, ecTrm s)::p -> crctTerm p 0 s.
Proof.
  induction 1; intros; subst;
    try (inversion_Clear H; assumption);
    try (eapply IHcrctTerm; reflexivity);
    try (eapply IHcrctTerm1; reflexivity).
  - myInjection H1. assumption.
  - discriminate.
Qed.

Lemma Crct_LookupDfn_Crct:
  forall p, crctEnv p -> forall nm t, LookupDfn nm p t -> crctTerm p 0 t.
Proof.
  intros. eapply pre_Crct_LookupDfn_Crct; eassumption.
Qed.

Lemma Crct_invrt_Const:
  forall p n const, crctTerm p n const ->
  forall nm, const = TConst nm ->
       exists pd, (LookupDfn nm p pd /\ crctTerm p 0 pd).
Proof.
  induction 1; intros; try discriminate. myInjection H1. 
  pose proof (Crct_LookupDfn_Crct H H0). exists pd. intuition.
Qed.

Lemma Crct_invrt_Lam:
  forall p n nm bod, crctTerm p n (TLambda nm bod) -> crctTerm p (S n) bod.
Proof.
  intros. inversion_Clear H. assumption.
Qed.

Lemma Crct_invrt_LetIn:
  forall p n nm dfn bod, crctTerm p n (TLetIn nm dfn bod) ->
     crctTerm p n dfn /\ crctTerm p (S n) bod.
Proof.
   intros. inversion_Clear H. intuition.
Qed.

Lemma Crct_invrt_App:
  forall p n fn arg,
    crctTerm p n (TApp fn arg) -> crctTerm p n fn /\ crctTerm p n arg.
Proof.
   intros. inversion_Clear H. intuition.
Qed.

Lemma Crct_invrt_Case:
  forall p n i s us,
    crctTerm p n (TCase i s us) -> crctTerm p n s /\ crctBs p n us /\ crctAnnot p i us.
Proof.
   intros. inversion_Clear H. intuition.
Qed.

Lemma Crct_invrt_Fix:
  forall p n ds m, crctTerm p n (TFix ds m) ->
                   crctDs p (n + dlength ds) ds.
Proof.
   intros. inversion_Clear H. intuition.
Qed.

Lemma Crct_invrt_Construct:
  forall p n ipkgNm inum cnum args,
    crctTerm p n (TConstruct (mkInd ipkgNm inum) cnum args) ->
    crctTerms p n args /\
    exists itypk,
      LookupTyp ipkgNm p 0 itypk /\
      exists (ip:ityp), getInd itypk inum = Ret ip /\
                        exists (ctr:Cnstr), getCnstr ip cnum = Ret ctr /\
                                            CnstrArity ctr = tlength args.
Proof.
  intros. inversion_Clear H. intuition. exists ipkg. intuition.
  exists itp. intuition. exists cstr. intuition.
Qed.

Lemma pre_CrctDs_invrt:
  forall m dts x, dnth m dts = Some x ->
     forall p n, crctDs p n dts ->
                 crctTerm p n (dbody x).
Proof.
    intros m dts. functional induction (dnth m dts); intros.
  - discriminate.
  - myInjection H. cbn. inversion_Clear H0; try assumption.
  - specialize (IHo _ H). inversion_Clear H0.
    + discriminate.
    + eapply IHo. assumption.
Qed.

Lemma CrctDs_invrt:
  forall m dts x, dnthBody m dts = Some x ->
    forall p n, crctDs p n dts -> crctTerm p n x.
Proof.
  intros. functional induction (dnthBody m dts).
  - discriminate.
  - myInjection H. inversion_Clear H0; try assumption.
  - inversion_Clear H0.
    + inversion H.
    + intuition.
Qed.

Lemma CrctBs_invrt:
  forall n p dts, crctBs p n dts -> 
    forall m x ix, bnth m dts = Some (x, ix) -> crctTerm p n x.
Proof.
  induction 1; intros.
  - inversion H0.
  - destruct m0.
    + cbn in H1. myInjection H1. assumption.
    + eapply IHcrctBs. cbn in H1. eassumption.
Qed.

Lemma Crcts_append:
  forall p n ts, crctTerms p n ts ->
  forall us, crctTerms p n us -> crctTerms p n (tappend ts us).
Proof.
  induction 1; intros us h; simpl.
  - assumption.
  - constructor; intuition.
Qed.

Lemma mkApp_pres_Crct:
  forall p n args, crctTerms p n args ->
                   forall fn, crctTerm p n fn ->
                              crctTerm p n (mkApp fn args).
Proof.
  induction 1; intros; cbn.
  - assumption.
  - apply IHcrctTerms. constructor; assumption.
Qed.

Lemma Instantiate_pres_Crct:
  forall tin, 
    (forall n bod ins,
       Instantiate tin n bod ins ->
       forall m p, n <= m -> crctTerm p (S m) bod -> crctTerm p m tin ->
                   crctTerm p m ins) /\
    (forall n bods inss,
       Instantiates tin n bods inss ->
       forall m p, n <= m -> crctTerms p (S m) bods -> crctTerm p m tin ->
                   crctTerms p m inss) /\
    (forall n bods inss,
       InstantiateBrs tin n bods inss ->
       forall m p, n <= m -> crctBs p (S m) bods -> crctTerm p m tin ->
                   crctBs p m inss) /\
    (forall n ds ids,
       InstantiateDefs tin n ds ids ->
       forall m p, n <= m -> crctDs p (S m) ds -> crctTerm p m tin ->
                   crctDs p m ids).
Proof.
  intros tin.
  apply InstInstsBrsDefs_ind; intros; trivial;
  try (inversion_Clear H0; econstructor; eassumption);
  try (inversion_Clear H1; constructor; try assumption; apply H; assumption).
  - inversion_Clear H0. constructor. assumption. omega.
  - apply ctRel.
    + inversion H0. assumption.
    + inversion H0. omega.
  - inversion_Clear H1. constructor; try assumption.
    apply H; try assumption. omega. apply (proj1 Crct_up). assumption.
  - inversion_Clear H2. constructor; try assumption.
    + apply H; assumption.
    + apply H0. omega. assumption. apply (proj1 Crct_up). assumption.
  - inversion_Clear H2. econstructor; try eassumption.
    + apply H; try eassumption.
    + apply H0; try eassumption.
  - inversion_Clear H1. econstructor; try eassumption.
    rewrite H11. erewrite Instantiates_pres_tlength; try eassumption.
    reflexivity.
    apply H; try eassumption.
  - inversion_Clear H2. constructor; try assumption.
    + apply H; try eassumption.
    + apply H0; try eassumption.
    + destruct i as [ind k].
      destruct H11 as (pack&ityp&Hlook&Hget&Hann).
      exists pack, ityp; intuition auto.
      destruct ityp. simpl in *. clear H H0; revert Hann its i1; clear.
      induction 1; inversion_clear 1; constructor; auto.
  - pose proof (InstantiateDefs_pres_dlength i) as k.
    inversion_Clear H1. constructor; try omega. apply H. omega.
    + replace (S (m0 + dlength id)) with (S m0 + dlength d); try omega.
      assumption.
    + eapply Crct_UP. eassumption. omega.
  - inversion_Clear H2. apply ctsCons; intuition.
  - inversion_Clear H2. constructor; intuition.
  - inversion_Clear H2.
    + inversion_Clear i0. apply cdsNil. assumption.
      * apply H; intuition.
      * eapply Instantiate_pres_isLambda; eassumption.
    + constructor.
      * apply H; intuition.
      * eapply Instantiate_pres_isLambda; eassumption.
      * apply H0; intuition.
Qed.

(**********
Lemma Instantiate_pres_WFTrm:
  forall tin,
  (forall n bod ibod,
      Instantiate tin n bod ibod ->
      forall m, m <= n -> WFTrm bod m -> WFTrm tin m -> WFTrm ibod m) /\
  (forall n bods ibods,
      Instantiates tin n bods ibods ->
      forall m, m <= n -> WFTrms bods m -> WFTrm tin m -> WFTrms ibods m) /\
  (forall n ts ss,
      InstantiateBrs tin n ts ss ->
      forall m, m <= n -> WFTrmBs ts m -> WFTrm tin m -> WFTrmBs ss m) /\
  (forall n ts ss,
      InstantiateDefs tin n ts ss ->
      forall m, m <= n -> WFTrmDs ts m -> WFTrm tin m -> WFTrmDs ss m).
Proof.
  intros tin. apply InstInstsBrsDefs_ind; intros; trivial;
  try (inversion_Clear H1; constructor; try assumption; apply H; assumption).
  - inversion_Clear H0. constructor. omega.
  - inversion_Clear H1. constructor; try assumption.
    apply H; try assumption. omega. apply (proj1 WFTrm_up). assumption.
  - inversion_Clear H2. constructor; try assumption.
    + apply H; assumption.
    + apply H0. omega. assumption. apply (proj1 WFTrm_up). assumption.
   - inversion_Clear H2. econstructor; try eassumption.
    + apply H; try eassumption.
    + apply H0; try eassumption.
  - inversion_Clear H2. constructor; try assumption.
    + apply H; try eassumption.
    + apply H0; try eassumption.
  - pose proof (InstantiateDefs_pres_dlength i) as k.
    inversion_Clear H1. econstructor; try omega.
    + eapply H; try omega; rewrite <- k. assumption.
      * eapply WFTrm_Up. eassumption. omega.
  - inversion_Clear H2. apply wfcons; intuition.
  - inversion_Clear H2. constructor; intuition.
  - inversion_Clear H2.
    + constructor; intuition.
      * eapply Instantiate_pres_isLambda; eassumption.
Qed.

Lemma instantiate_pres_WFTrm:
  forall m bod, WFTrm bod m -> forall tin, WFTrm tin m -> 
                  forall n, m <= n -> WFTrm (instantiate tin n bod) m.
Proof.
  intros.
  apply (proj1 (Instantiate_pres_WFTrm tin) n bod); try assumption.
  refine (proj1 (instantiate_Instantiate tin) _ _).
Qed.
 *******************)

Lemma instantiate_pres_Crct:
  forall p m bod, crctTerm p (S m) bod -> forall tin, crctTerm p m tin -> 
                  forall n, n <= m -> crctTerm p m (instantiate tin n bod).
Proof.
  intros.
  refine (proj1 (Instantiate_pres_Crct tin) _ _ _ _ _ _ _ _ _);
    try eassumption.
  refine (proj1 (instantiate_Instantiate tin) _ _).
Qed.

Lemma whBetaStep_pres_Crct:
  forall p n bod, crctTerm p (S n) bod ->
                  forall a1, crctTerm p n a1 ->
                             crctTerm p n (whBetaStep bod a1).
Proof.
  intros. unfold whBetaStep. 
  apply instantiate_pres_Crct; try assumption. omega.
Qed.

Lemma bnth_pres_Crct:
  forall p n (brs:Brs), crctBs p n brs ->
    forall m x ix, bnth m brs = Some (x, ix) -> crctTerm p n x.
Proof.
  intros p n brs h m x ix.
  functional induction (bnth m brs); intros; auto.
  - discriminate.
  - myInjection H. inversion h. assumption.
  - apply IHo; inversion h; assumption.
Qed.

Lemma whCaseStep_pres_Crct:
  forall p n ts, crctTerms p n ts -> forall brs, crctBs p n brs ->
  forall m s, whCaseStep m ts brs = Some s -> crctTerm p n s.
Proof.
  intros p n ts h1 brs h2 m s h3. unfold whCaseStep in h3.
  assert (j: bnth m brs = None \/ (exists t, bnth m brs = Some t)).
  { destruct (bnth m brs).
    + right. exists p0. reflexivity.
    + left. reflexivity. }
  destruct j.
  - rewrite H in h3. discriminate.
  - destruct H as [x jx]. rewrite jx in h3. destruct x as [y0 y1].
    myInjection h3. apply mkApp_pres_Crct; try assumption.
    eapply (bnth_pres_Crct h2). eassumption.
Qed.

Lemma fold_left_pres_Crct:
  forall (f:Term -> nat -> Term) (ns:list nat) p (a:nat),
    (forall u m, m >= a -> crctTerm p (S m) u ->
               forall n, In n ns -> crctTerm p m (f u n)) ->
    forall t, crctTerm p (a + List.length ns) t ->
              crctTerm p a (fold_left f ns t).
Proof.
  intros f. induction ns; cbn; intros.
  - replace (a + 0) with a in H0. assumption. omega.
  - apply IHns.
    + intros. apply H; try assumption. apply (or_intror H3).
    + replace (a0 + S (Datatypes.length ns))
        with (S (a0 + (Datatypes.length ns))) in H0.
      assert (j: a0 + Datatypes.length ns >= a0). omega.
      specialize (H t _ j H0).
      apply H. apply (or_introl eq_refl). omega.
Qed.

Lemma dnth_crctDs_crctTerm:
  forall m dts fs, dnth m dts = Some fs ->
                   forall p n, crctDs p n dts -> crctTerm p n (dbody fs).
Proof.
  intros m dts fs.
  functional induction (dnth m dts); intros; try discriminate.
  - inversion_Clear H0.
    + myInjection H. cbn. assumption.
    + myInjection H. cbn. assumption.
  - inversion_Clear H0.
    + discriminate.
    + apply IHo; try assumption.
Qed.

Lemma dnthBody_pres_Crct:
  forall m dts fs, dnthBody m dts = Some fs ->
                   forall p n, crctDs p n dts -> crctTerm p n fs.
Proof.
  intros m dts fs.
  functional induction (dnthBody m dts); intros; try discriminate.
  - myInjection H. inversion_Clear H0; try assumption.
  - inversion_Clear H0.
    + inversion H.
    + intuition. 
Qed.

Lemma whFixStep_pres_Crct:
  forall (dts:Defs) p n,
    crctDs p (n + dlength dts) dts ->
    forall m s, whFixStep dts m = Some s -> crctTerm p n s.
Proof.
  unfold whFixStep. intros. case_eq (dnthBody m dts); intros.
  - assert (j: m < dlength dts).
    { eapply dnthBody_lt. eassumption. }
    rewrite H1 in H0. myInjection H0. apply fold_left_pres_Crct. 
    + intros. apply instantiate_pres_Crct; try omega. assumption.
      * pose proof (In_list_to_zero _ _ H3) as j0.
        constructor; try assumption.
        pose proof (dnthBody_pres_Crct _ H1 H) as k2.
        eapply CrctDs_Up. eassumption. omega.
    + rewrite list_to_zero_length.
      eapply dnthBody_pres_Crct. eassumption.
      eapply CrctDs_Up. eassumption. omega.
  - rewrite H1 in H0. discriminate.
Qed.


(***********************  old  ************************

(** correctness specification for programs (including local closure) **)
Inductive Crct: (environ Term) -> nat -> Term -> Prop :=
| CrctWkTrmTrm: forall n p t s nm, Crct p n t -> Crct p n s ->
           fresh nm p -> Crct ((nm,ecTrm s)::p) n t
| CrctWkTrmTyp: forall n p t s nm, Crct p n t -> CrctTyp p n s ->
           fresh nm p -> forall m, Crct ((nm,ecTyp _ m s)::p) n t
| CrctRel: forall n m p, m < n -> Crct p n prop -> Crct p n (TRel m)
| CrctLam: forall n p nm bod,
            Crct p n prop -> Crct p (S n) bod -> Crct p n (TLambda nm bod)
| CrctLetIn: forall n p nm dfn bod,
         Crct p n dfn -> Crct p (S n) bod -> 
         Crct p n (TLetIn nm dfn bod)
| CrctApp: forall n p fn a,  ~ (isConstruct fn) ->
             Crct p n fn -> Crct p n a -> Crct p n (TApp fn a)
| CrctConst: forall n p pd nm,
               Crct p n prop -> LookupDfn nm p pd -> Crct p n (TConst nm)
| CrctConstruct: forall n p ipkgNm npars itypk inum cnum args,
                   Crct p n prop -> LookupTyp ipkgNm p npars itypk ->
                   CrctCnstr itypk inum cnum (tlength args) ->
                   Crcts p n args ->
                   Crct p n (TConstruct (mkInd ipkgNm inum) cnum args)
| CrctCase: forall n p m mch brs,
          (***    CrctAnnot p m brs ->  ***)
              Crct p n mch -> CrctDs p n brs ->
              Crct p n (TCase m mch brs)
| CrctFix: forall n p ds m,
             Crct p n prop ->    (** convenient for IH *)
             CrctDs p (n + dlength ds) ds -> Crct p n (TFix ds m)
with Crcts: environ Term -> nat -> Terms -> Prop :=
| CrctsNil: forall n p, Crct p n prop -> Crcts p n tnil
| CrctsCons: forall n p t ts,
               Crct p n t -> Crcts p n ts -> Crcts p n (tcons t ts)
with CrctDs: environ Term -> nat -> Defs -> Prop :=
| CrctDsNil: forall n p, Crct p n prop -> CrctDs p n dnil
| CrctDsCons: forall n p dn db dra ds,
          Crct p n db -> CrctDs p n ds -> CrctDs p n (dcons dn db dra ds)
with CrctTyp: environ Term -> nat -> itypPack -> Prop := 
| CrctTypStart: forall n itp, CrctTyp nil n itp
| CrctTypWk1: forall n p t s nm, CrctTyp p n t -> Crct p n s ->
           fresh nm p -> CrctTyp ((nm,ecTrm s)::p) n t
| CrctTypWk2: forall n p t s nm, CrctTyp p n t -> CrctTyp p n s ->
           fresh nm p -> forall m, CrctTyp ((nm,ecTyp _ m s)::p) n t.
Hint Constructors Crct Crcts CrctDs CrctTyp.
Scheme Crct_ind' := Minimality for Crct Sort Prop
  with Crcts_ind' := Minimality for Crcts Sort Prop
  with CrctDs_ind' := Minimality for CrctDs Sort Prop
  with CrctTyp_ind' := Minimality for CrctTyp Sort Prop.
Combined Scheme CrctCrctsCrctDsTyp_ind from
         Crct_ind', Crcts_ind', CrctDs_ind', CrctTyp_ind'.
Combined Scheme CrctCrctsCrctDs_ind from Crct_ind', Crcts_ind', CrctDs_ind'.
 
Lemma Crct_WFTrm:
  (forall p n t, Crct p n t -> WFTrm t n) /\
  (forall p n ts, Crcts p n ts -> WFTrms ts n) /\
  (forall (p:environ Term) (n:nat) (ds:Defs), CrctDs p n ds -> WFTrmDs ds n) /\
  (forall (p:environ Term) (n:nat) (itp:itypPack), CrctTyp p n itp -> True).
  apply CrctCrctsCrctDsTyp_ind; intros; try auto; try (solve [constructor]).
Qed.

Lemma Crct_up:
  (forall p n t, Crct p n t -> Crct p (S n) t) /\
  (forall p n ts, Crcts p n ts -> Crcts p (S n) ts) /\
  (forall (p:environ Term) (n:nat) (ds:Defs),
     CrctDs p n ds -> CrctDs p (S n) ds) /\
  (forall (p:environ Term) (n:nat) (itp:itypPack),
     CrctTyp p n itp -> CrctTyp p (S n) itp).
Proof.
  apply CrctCrctsCrctDsTyp_ind; intros;
  try (solve[econstructor; try eassumption; try omega]).
Qed.


Lemma Crct_Sort:
  forall p n t, Crct p n t -> forall srt, Crct p n (TSort srt).
induction 1; intuition.
Qed.

(** Tail preserves correctness **)
Lemma CrctTrmTl:
  forall pp n t, Crct pp n t ->
             forall nm s p, pp = ((nm,ecTrm s)::p) -> Crct p n s.
induction 1; intros;
try (solve [eapply IHCrct2; eassumption]);
try (solve [eapply IHCrct; eassumption]);
try (solve [eapply IHCrct1; eassumption]);
try discriminate.
- injection H2; intros. subst. assumption.
Qed.

Lemma CrctTypTl:
  forall pp n t, Crct pp n t ->
    forall nm npars tp p, pp = ((nm,ecTyp _ npars tp)::p) -> CrctTyp p n tp.
induction 1; intros; try discriminate;
try (solve [eapply IHCrct2; eassumption]);
try (solve [eapply IHCrct; eassumption]);
try (solve [eapply IHCrct1; eassumption]).
- injection H2; intros. subst. assumption.
Qed.

Lemma Crct_fresh_Pocc:
  (forall p n t, Crct p n t -> forall nm, fresh nm p -> ~ PoccTrm nm t) /\
  (forall p n ts, Crcts p n ts -> forall nm, fresh nm p -> ~ PoccTrms nm ts) /\
  (forall p n (ds:Defs), CrctDs p n ds -> forall nm, fresh nm p ->
                                                     ~ PoccDefs nm ds) /\
  (forall (p:environ Term) (n:nat) (itp:itypPack), CrctTyp p n itp -> True).
Proof.
  apply CrctCrctsCrctDsTyp_ind; intros; try intros j; auto;
  try (solve [inversion j]);
  try (solve [inversion_clear j; elim (H0 nm); trivial]);
  try (solve [inversion_clear j; elim (H0 nm); trivial; elim (H2 nm); trivial]);
  try (solve [inversion_clear j; elim (H0 nm0); trivial;
              elim (H2 nm0); trivial]);
  try (solve [inversion_clear j; elim (H0 nm); trivial; elim (H2 nm); trivial]);
  try (solve [inversion_clear H4; elim (H0 nm0); trivial]).
  - inversion j; subst.
    + elim (H1 _ H4). assumption.
    + elim (H3 _ H4). assumption.
  - inversion j. subst.
    elim (@fresh_Lookup_fails _ _ _ (ecTrm pd) H2). assumption.
  - inversion_Clear j. destruct H1. 
    + eelim (fresh_Lookup_fails H5). eassumption.
    + eelim H4; eassumption.
      (***************
  - inversion j. subst.
    (********
  + red in H. apply fresh_lookup_None in H4. rewrite H4 in H. auto.
  + inversion_clear j; elim (H1 nm); trivial; elim (H3 nm); trivial.
  + inversion_clear j; elim (H1 nm); trivial; elim (H3 nm); trivial.
     **************)
    + specialize (H0 _ H3); contradiction.
    + specialize (H2 _ H3); contradiction.
****************)
Qed.

Lemma Crct_not_bad_Lookup:
  (forall p n s, Crct p n s ->
                 forall nm, LookupDfn nm p (TConst nm) -> False) /\
  (forall p n ss, Crcts p n ss ->
                 forall nm, LookupDfn nm p (TConst nm) -> False) /\
  (forall p n ds, CrctDs p n ds ->
                 forall nm, LookupDfn nm p (TConst nm) -> False) /\
  (forall (p:environ Term) (n:nat) (itp:itypPack), CrctTyp p n itp -> True).
apply CrctCrctsCrctDsTyp_ind; intros; auto;
try (solve [elim (H0 _ H3)]); try (solve [elim (H0 _ H5)]);
try (solve [elim (H1 _ H2)]); try (solve [elim (H1 _ H3)]);
try (solve [elim (H0 _ H1)]); try (solve [elim (H0 _ H2)]).
- inversion H.
- destruct (string_dec nm0 nm).
  + subst. inversion_Clear H4.
    * assert (j:= proj1 Crct_fresh_Pocc _ _ _ H1 _ H3).
      elim j. constructor.
    * elim (H0 _ H11).
  + refine (H0 _ (Lookup_strengthen H4 eq_refl n0)).
- elim (H0 nm0). unfold LookupDfn in H4. unfold LookupDfn.
  destruct (string_dec nm0 nm).
  + subst. inversion H4. assumption.
  + refine (Lookup_strengthen H4 eq_refl _). assumption.
- elim (H1 _ H4).
  (**
- elim (H1 _ H4).
***)
Qed.

Lemma  Crct_weaken:
  (forall p n t, Crct p n t -> 
    forall nm s, fresh nm p -> Crct p n s -> Crct ((nm,ecTrm s)::p) n t) /\
  (forall p n ts, Crcts p n ts -> 
    forall nm s, fresh nm p -> Crct p n s -> Crcts ((nm,ecTrm s)::p) n ts) /\
  (forall p n ds, CrctDs p n ds -> 
    forall nm s, fresh nm p -> Crct p n s -> CrctDs ((nm,ecTrm s)::p) n ds) /\
  (forall p n itp, CrctTyp p n itp -> 
    forall nm s, fresh nm p -> Crct p n s -> CrctTyp ((nm,ecTrm s)::p) n itp).
eapply CrctCrctsCrctDsTyp_ind; intros; intuition.
- apply CrctWkTrmTrm; try assumption. eapply CrctConst; try eassumption.
- destruct H1. eapply CrctConstruct; try eassumption.
  + apply H0; assumption. 
  + split; try apply Lookup_weaken; eassumption.
  + apply H4; assumption.
Qed.


Lemma  Crct_Typ_weaken:
  (forall p n t, Crct p n t -> 
    forall nm itp, fresh nm p -> CrctTyp p n itp ->
                   forall npars, Crct ((nm,ecTyp _ npars itp)::p) n t) /\
  (forall p n ts, Crcts p n ts -> 
    forall nm itp, fresh nm p -> CrctTyp p n itp ->
                 forall npars, Crcts ((nm,ecTyp _ npars itp)::p) n ts) /\
  (forall p n ds, CrctDs p n ds -> 
    forall nm itp, fresh nm p -> CrctTyp p n itp ->
                   forall npars, CrctDs ((nm,ecTyp _ npars itp)::p) n ds) /\
  (forall p n jtp, CrctTyp p n jtp -> 
    forall nm itp, fresh nm p -> CrctTyp p n itp ->
                  forall npars,  CrctTyp ((nm,ecTyp _ npars itp)::p) n jtp).
Proof.
  eapply CrctCrctsCrctDsTyp_ind; intros; auto.
  - apply CrctWkTrmTyp; try assumption. eapply CrctConst; try eassumption.
  - destruct H1. eapply CrctConstruct; try eassumption.
    + apply H0; try assumption. 
    + split; try apply Lookup_weaken; eassumption.
    + apply H4; try assumption.
Qed.

Lemma Crct_strengthen:
  (forall pp n s, Crct pp n s -> forall nm ec p, pp = (nm,ec)::p ->
                 ~ PoccTrm nm s -> Crct p n s) /\
  (forall pp n ss, Crcts pp n ss -> forall nm ec p, pp = (nm,ec)::p ->
                 ~ PoccTrms nm ss -> Crcts p n ss) /\
  (forall pp n ds, CrctDs pp n ds -> forall nm ec p, pp = (nm,ec)::p ->
                 ~ PoccDefs nm ds -> CrctDs p n ds) /\
  (forall (pp:environ Term) (n:nat) (itp:itypPack), CrctTyp pp n itp -> True).
Proof.
  apply CrctCrctsCrctDsTyp_ind; intros; auto.
  - discriminate.
  - injection H4; intros. subst. assumption.
  - injection H4; intros. subst. assumption.
  - apply CrctRel; try assumption. eapply H1. eapply H2.
    intros h. inversion h.
  - apply CrctProd.
    + eapply H0. eassumption.
      intros h. inversion h.
    + eapply H2. eassumption.
      intros h. elim H4. apply PoProdBod. assumption.
  - apply CrctLam.
    + eapply H0. eassumption.
      intros h. inversion h.
    + eapply H2. eassumption.
      intros h. elim H4. apply PoLambdaBod. assumption.
  - apply CrctLetIn.
    + eapply H0. eassumption.
      intros h. elim H4. apply PoLetInDfn. assumption.
    + eapply H2. eassumption.
      intros h. elim H4. apply PoLetInBod. assumption.
  - apply CrctApp; try assumption.
    + eapply H1. eassumption.
      intros h. elim H5. apply PoAppL. assumption.
    + eapply H3. eassumption.
      intros h. elim H5. apply PoAppA. assumption.
  - eapply CrctConst. eapply H0. eapply H2.
    intros h. inversion h. rewrite H2 in H1.
    assert (j: nm0 <> nm).
    { apply notPocc_TConst. assumption. }
    inversion H1.
    + rewrite H6 in j. nreflexivity j.
    + eassumption.
  - eapply CrctConstruct; try eassumption.
    + eapply H0. eapply H5. intros h. inversion h.
    + rewrite H5 in H1.
      assert (j: nm <> ipkgNm).
      { eapply notPocc_TCnstr. eassumption. }
      destruct H1. subst. split; try assumption.
      inversion_Clear H1.
      * elim j. reflexivity.
      * eassumption.
    + eapply H4; try eassumption.
      intros h. destruct H6. apply PoCnstrA. assumption.
  - apply CrctCase.
    (************
    + red. destruct m as [[[mind n0] pars] args].
      simpl in H. rewrite H4 in H. simpl in H.
      revert H; case_eq (string_eq_bool mind nm); auto.
      intros. elim H5. apply string_eq_bool_eq in H. subst mind.
      constructor.
*********************)
    + eapply H0. eassumption.
      intros h. elim H4. apply PoCaseL. assumption.
    + eapply H2. eassumption.
      intros h. elim H4. apply PoCaseR. assumption.
  - apply CrctFix.
    + eapply H0. eassumption. intros h. inversion h.
    + eapply H2. eassumption. intros h. elim H4. apply PoFix. assumption.
  - apply CrctInd. apply (H0 _ _ _ H1). inversion 1. 
  - apply CrctsNil. rewrite H1 in H. inversion H; assumption.
  - apply CrctsCons.
    + eapply H0. eassumption. intros h. elim H4. apply PoThd. assumption.
    + eapply H2. eassumption.
      intros h. elim H4. apply PoTtl. assumption.
  - apply CrctDsNil. eapply H0. eassumption. intros h. inversion h.
  - apply CrctDsCons.
    + eapply H0. eassumption. intros h. elim H4. apply PoDhd_bod. assumption.
    + eapply H2. eassumption. intros h. elim H4. apply PoDtl. assumption.
Qed.

(** Crct inversions **)
Lemma LookupDfn_pres_Crct:
  forall p n t, Crct p n t -> forall nm u, LookupDfn nm p u -> Crct p n u.
Proof.
assert (lem: (forall p n t, Crct p n t -> 
                            forall nm u, LookupDfn nm p u -> Crct p n u) /\
             (forall p n ts, Crcts p n ts -> True) /\
             (forall (p:environ Term) (n:nat) (ds:Defs),
                CrctDs p n ds -> True) /\
             (forall (p:environ Term) (n:nat) (itp:itypPack),
                CrctTyp p n itp -> True)).
  { apply CrctCrctsCrctDsTyp_ind; intros; auto;
    try (solve [eapply H1; eassumption]);
    try (solve [eapply H2; eassumption]);
    try (solve [eapply H0; eassumption]).
    - inversion H.
    - apply CrctWkTrmTrm; try assumption. inversion H4; subst.
      + assumption.
      + eapply H0. apply H11.
    - apply CrctWkTrmTyp; try assumption. inversion H4; subst.
      eapply H0. eassumption.
  }
  apply (proj1 lem).
Qed.


Lemma Crct_invrt_Rel:
  forall p n rel, Crct p n rel -> forall m, rel = TRel m ->
     m < n /\ Crct p n prop.
Proof.
  induction 1; intros; try discriminate.
  - assert (j:= IHCrct1 m). intuition.
  - assert (j:= IHCrct m). specialize (IHCrct _ H2). intuition.
  - assert (j:= IHCrct m). injection H1. intuition.
Qed.

Lemma Crct_invrt_WkTrm:
  forall (ev:environ Term) n t, Crct ev n t ->
  forall nm s p, ev = (nm, ecTrm s)::p -> Crct p n s.
Proof.
  induction 1; intros; try discriminate;
  try (solve [eapply IHCrct2; eassumption]);
  try (solve [eapply IHCrct1; eassumption]);
  try (solve [eapply IHCrct; eassumption]).
  - injection H2; intros; subst. assumption.
Qed.

Lemma Crct_invrt_Const:
  forall p n const, Crct p n const ->
  forall nm, const = TConst nm ->
       (Crct p n prop /\ exists pd, LookupDfn nm p pd /\ Crct p n pd).
Proof.
  induction 1; intros; try discriminate.
  - assert (j:= IHCrct1 _ H2). intuition.
    destruct H4 as [x [h2 h3]]. exists x. split.
    + assert (j: nm0 <> nm).
      { destruct (string_dec nm0 nm). 
        - subst. elim (fresh_Lookup_fails H1 h2).
        - assumption. }
      apply (LMiss _ j). trivial.
    + apply CrctWkTrmTrm; trivial.
  - assert (j:= IHCrct _ H2). intuition.
    destruct H4 as [x [h2 h3]]. exists x. split.
    + assert (j: nm0 <> nm).
      { destruct (string_dec nm0 nm). 
        - subst. elim (fresh_Lookup_fails H1 h2).
        - assumption. }
      apply (LMiss _ j). trivial.
    + apply CrctWkTrmTyp; trivial.
  - injection H1. intros. subst. intuition. exists pd; intuition.
    eapply LookupDfn_pres_Crct; eassumption.
Qed.

Lemma Crct_invrt_Prod:
  forall p n prod, Crct p n prod ->
  forall nm bod, prod = TProd nm bod -> Crct p (S n) bod.
Proof.
  induction 1; intros; try discriminate.
  - assert (j:= IHCrct1 _ _ H2).
    apply CrctWkTrmTrm; trivial.
    apply (proj1 Crct_up). assumption.
  - assert (j:= IHCrct _ _ H2).
    apply CrctWkTrmTyp; trivial.
    apply (proj2 (proj2 (Crct_up))). assumption.    
  - injection H1. intros. subst. assumption.
Qed.

Lemma Crct_invrt_Lam:
  forall p n lam, Crct p n lam ->
  forall nm bod, lam = TLambda nm bod -> Crct p (S n) bod.
Proof.
  induction 1; intros; try discriminate.
  - assert (j:= IHCrct1 _ _ H2).
    apply CrctWkTrmTrm; trivial.
    apply (proj1 Crct_up). assumption.
  - assert (j:= IHCrct _ _ H2).
    apply CrctWkTrmTyp; trivial.
    apply (proj2 (proj2 (Crct_up))). assumption.    
  - injection H1. intros. subst. assumption.
Qed.

Lemma Crct_invrt_LetIn:
  forall p n letin, Crct p n letin ->
  forall nm dfn bod, letin = TLetIn nm dfn bod ->
     Crct p n dfn /\ Crct p (S n) bod.
Proof.
  induction 1; intros; try discriminate.
  - assert (j:= IHCrct1 _ _ _ H2). intuition.
    apply CrctWkTrmTrm; trivial.
    apply (proj1 (Crct_up)). assumption.
  - assert (j:= IHCrct _ _ _ H2). intuition.
    apply (CrctWkTrmTyp); trivial.
    apply (proj2 (proj2 Crct_up)). assumption.
  - injection H1. intros. subst. intuition.
Qed.

Lemma Crct_invrt_App:
  forall p n app,
    Crct p n app -> forall fn arg, app = (TApp fn arg) ->
                                   Crct p n fn /\ Crct p n arg /\ ~ isConstruct fn.
Proof.
  induction 1; intros; try discriminate.
  - assert (j:= IHCrct1 _ _ H2); intuition.
  - assert (j:= IHCrct _ _ H2). intuition.
  - myInjection H2. intuition.
Qed.

Lemma CrctAnnot_weaken nm (p: environ Term) m brs d:
  CrctAnnot p m brs -> fresh nm p ->
  CrctAnnot ((nm, d) :: p) m brs.
Proof.
  intros HC Hf.
  red. destruct m, i. cbn.
  cbn in HC.
  case_eq (string_eq_bool s nm); intros; auto.
  pose proof (string_eq_bool_eq _ _ H). subst nm.
  rewrite (proj1 (fresh_lookup_None _ _) Hf) in HC. contradiction.
Qed.

Lemma Crct_invrt_Case:
  forall p n case, Crct p n case ->
  forall m s us, case = (TCase m s us) -> Crct p n s /\ CrctDs p n us.
  (***************
    CrctAnnot p m us /\ Crct p n s /\ CrctDs p n us.
*******************)
Proof.
  induction 1; intros; try discriminate.
  - assert (j:= IHCrct1 _ _ _ H2). intuition.
(**    apply CrctAnnot_weaken; auto. **)
    apply (proj2 Crct_weaken); auto.
  - assert (j:= IHCrct _ _ _ H2). intuition.
 (**   apply CrctAnnot_weaken; auto. **)
    apply (proj2 (proj2 Crct_Typ_weaken)); auto.
  - myInjection H1. intuition. 
Qed.

Lemma Crct_invrt_Fix:
  forall p n gix, Crct p n gix ->
  forall ds m, gix = (TFix ds m) -> CrctDs p (n + dlength ds) ds.
induction 1; intros; try discriminate.
- assert (j:= IHCrct1 _ _ H2). intuition.
  apply (proj2 Crct_weaken); auto.
  + generalize (dlength ds). induction n0.
    * rewrite <- plus_n_O. assumption.
    * rewrite <- plus_n_Sm. apply Crct_up. assumption.
- assert (j:= IHCrct _ _ H2). 
  apply (proj1 (proj2 (proj2 Crct_Typ_weaken))); auto.
  + generalize (dlength ds). induction n0.
    * rewrite <- plus_n_O. assumption.
    * rewrite <- plus_n_Sm. apply Crct_up. assumption.
- injection H1; intros; subst. assumption.
Qed.

Lemma Crct_invrt_Construct:
  forall p n construct, Crct p n construct ->
  forall ipkgNm inum cnum args,
    construct = (TConstruct (mkInd ipkgNm inum) cnum args) ->
    Crct p n prop /\ Crcts p n args /\
    exists npars itypk,
      LookupTyp ipkgNm p npars itypk /\
      CrctCnstr itypk inum cnum (tlength args).
induction 1; intros; try discriminate.
- assert (j:= IHCrct1 _ _ _ _ H2).
  intuition; destruct H6 as [npars [itypk [h1 h2]]].
  + apply (proj1 (proj2 Crct_weaken)); trivial.
  + destruct h1. exists npars, itypk. repeat split; try assumption.
    apply Lookup_weaken; trivial.
- assert (j:= IHCrct _ _ _ _ H2).
  intuition; destruct H6 as [npars [itypk [h1 h2]]].
  + apply (proj1 (proj2 Crct_Typ_weaken)); trivial.
  + exists npars, itypk. destruct h1. repeat split; try assumption.
    apply Lookup_weaken; trivial.
- injection H3; intros; subst. intuition.
  exists npars, itypk. intuition.
Qed.

Lemma Crcts_append:
  forall p n ts, Crcts p n ts ->
  forall us, Crcts p n us -> Crcts p n (tappend ts us).
Proof.
  induction 1; intros us h; simpl.
  - assumption.
  - apply CrctsCons; intuition.
Qed.

(*********
Lemma Instantiate_pres_is_n_lambda tin n t it k :
  Instantiate tin n t it ->
  is_n_lambda k t = true -> is_n_lambda k it = true.
Proof.
  intros H; revert k; induction H;
  simpl; intros; destruct k; 
  try (simpl in *; reflexivity || discriminate).
  simpl in H0. apply (IHInstantiate _ H0). 
Qed.

Lemma Instantiates_pres_is_n_lambda tin n ts its k :
  Instantiates tin n ts its ->
  forall i t, tnth i ts = Some t ->
         exists t', tnth i its = Some t' /\
               (is_n_lambda k t = true ->
                is_n_lambda k t' = true).
Proof.
  induction 1. simpl. intros. discriminate.
  intros.
  simpl in H1. destruct i.
  - injection H1. intros <-.
    exists it. intuition.
    eapply Instantiate_pres_is_n_lambda in H. apply H. apply H2.
  - destruct (IHInstantiates _ _ H1) as [t' [Hnth Hlam]].
    exists t'. intuition.
Qed.

Lemma Instantiates_pres_CrctAnnot tin n ts its p np :
  Instantiates tin n ts its ->
  CrctAnnot p np ts -> CrctAnnot p np its.
Proof.
  destruct np as [[[mind ind] pars] args]; intros i h1. simpl in *.
  destruct (lookup mind p); trivial. destruct e; trivial.
  destruct h1 as [h1 [h1' h1'']].
  intuition. red in h1'' |- *. intuition.
  now rewrite <- (Instantiates_pres_tlength i).
  specialize (H0 i1). destruct (nth_error args i1); trivial.
  revert H0; case_eq (tnth i1 ts). intros t Ht Hnt.
  destruct (Instantiates_pres_is_n_lambda n1 i _ Ht) as [t' [Hnt' Hnlam]].
  rewrite Hnt'. intuition. now intros _ Hf.
Qed.
*****************)
(*****
Lemma Instantiate_pres_Crct:
  forall tin, 
  (forall n bod ins, Instantiate tin n bod ins ->
  forall m p, n <= m -> Crct p (S m) bod -> Crct p m tin -> Crct p m ins) /\
  (forall n bods inss, Instantiates tin n bods inss ->
  forall m p, n <= m -> Crcts p (S m) bods -> Crct p m tin -> Crcts p m inss) /\
  (forall n ds ids, InstantiateDefs tin n ds ids ->
  forall m p, n <= m -> CrctDs p (S m) ds -> Crct p m tin -> CrctDs p m ids).
Proof.
  intros tin. apply InstInstsDefs_ind; intros; trivial.
  - apply CrctRel.
    + omega.
    + eapply Crct_Sort. eassumption.
  - destruct (Crct_invrt_Rel H0 eq_refl). apply CrctRel.
    + omega.
    + eapply Crct_Sort. eassumption.
  - eapply Crct_Sort; eassumption.
  - apply CrctProd. eapply Crct_Sort; eassumption.
    assert (j:= Crct_invrt_Prod H1 eq_refl).
    + apply H; trivial. omega. apply (proj1 Crct_up). assumption.
  -  apply CrctLam. eapply Crct_Sort; eassumption.
     assert (j:= Crct_invrt_Lam H1 eq_refl).
    + apply H; trivial. omega. apply (proj1 Crct_up). assumption.
  - destruct (Crct_invrt_LetIn H2 eq_refl). apply CrctLetIn.
    + apply H; trivial.
    + apply H0; intuition. apply (proj1 Crct_up). assumption.
  - destruct (Crct_invrt_App H2 eq_refl) as [j1 [j2 j3]]. apply CrctApp.
    + assumption.
    + inversion H2.
    + apply H; trivial.
    + apply H0; trivial.
  - edestruct (Crct_invrt_Const H0).
    + reflexivity.
    + destruct H3 as [x [h1 h2]]. eapply (@CrctConst _ _ x); trivial.
      * eapply Crct_Sort. eassumption.
  - apply CrctInd. eapply Crct_Sort. eassumption.
  - destruct ind. edestruct (Crct_invrt_Construct H1).
    + reflexivity.
    + destruct H4 as [npars [x [h1 [h2 h3]]]].
      eapply CrctConstruct; try eassumption.
      * eapply Crct_Sort. eassumption.
      * rewrite <- (Instantiates_pres_tlength i). apply h3; trivial.
      * apply H; auto.
  - destruct (Crct_invrt_Case H2 eq_refl) as [h1 [h2 h3]]. apply CrctCase.
    + eapply Instantiates_pres_CrctAnnot; eauto.
    + apply H; trivial.
    + apply H0; trivial.
  - assert (j:= Crct_invrt_Fix H1 eq_refl). apply CrctFix. 
    + eapply Crct_Sort. eassumption.
    + rewrite <- (InstantiateDefs_pres_dlength i). apply H. omega.
      * simpl in j. assumption.
      * simpl in j. generalize (dlength d). induction n0.
        rewrite <- plus_n_O. assumption.
        rewrite <- plus_n_Sm. apply (proj1 Crct_up). assumption.
  - apply CrctsNil. eapply Crct_Sort. eassumption.
  - inversion_Clear H2. apply CrctsCons.
    + apply H; trivial.
    + apply H0; trivial.
  - apply CrctDsNil. eapply Crct_Sort. eassumption.
  - inversion_Clear H2. apply CrctDsCons.
    + apply H; trivial.
    + apply H0; trivial.
Qed.
 ****)

(***
Lemma Crct_App_inv:
  forall p n fn a1 args, Crct p n (TApp fn a1 args) ->
                         Crct p n fn /\ Crct p n a1 /\ Crcts p n args.
intros p n fn a1 args h. split; try split. inversion_Clear h.
- inversion H; subst.
induction 1. try (intros; discriminate); intros h; subst; split; try split;
try (inversion_Clear h; assumption).
- eapply CrctWkTrmTrm; try eassumption. intuition.
- eapply CrctWkTrmTrm; try eassumption. intuition.
- assert (j:Crct p n fn /\ Crct p n a1 /\ Crcts p n args).
  apply IHCrct1; reflexivity.
  destruct j. destruct H3.
  eapply (CrctsWk H4); assumption. 
Qed.

Lemma Crct_App_inv:
  forall p n fn a1 args t, Crct p n t -> t = (TApp fn a1 args) ->
                         Crct p n fn /\ Crct p n a1 /\ Crcts p n args.
intros p n fn a1 args t h j. 
induction h; try (intros; discriminate). intros h. subst; split; try split;
try (inversion_Clear h; assumption).
- eapply CrctWkTrmTrm; try eassumption. intuition.
- eapply CrctWkTrmTrm; try eassumption. intuition.
- assert (j:Crct p n fn /\ Crct p n a1 /\ Crcts p n args).
  apply IHCrct1; reflexivity.
  destruct j. destruct H3.
  eapply (CrctsWk H4); assumption. 
Qed.
***)

(*********
(** An alternative correctness specification for programs: [crct], below **)
Definition weaklyClosed (t:Term) (p:environ Term) : Prop :=
  forall nm, PoccTrm nm t -> lookupDfn nm p <> None.
Fixpoint weaklyCloseds (ts:Terms) p : Prop :=
  match ts with
    | tnil => True
    | tcons s ss => weaklyClosed s p /\ weaklyCloseds ss p
  end.
Fixpoint weaklyClosedd (ds:Defs) p : Prop :=
  match ds with
    | dnil => True
    | dcons nm tb m es => weaklyClosed tb p /\ weaklyClosedd es p
  end.

Lemma weaklyClosed_TCase:
  forall n mch brs p, weaklyClosed (TCase n mch brs) p ->
            weaklyClosed mch p /\ weaklyCloseds brs p.
unfold weaklyClosed. intros n mch brs p h1. split.
- intros xnm h2. apply (h1 xnm). apply PoCaseL. assumption.
- induction brs; unfold weaklyCloseds. auto. split.
  + unfold weaklyClosed. intros xnm h2. apply (h1 xnm).
    apply PoCaseR. apply PoThd. assumption.
  + apply IHbrs. intros xnm h2. apply (h1 xnm). inversion_clear h2.
    apply PoCaseL. assumption.
    apply PoCaseR. apply PoTtl. assumption.
Qed.

Lemma Pocc_weakClsd_no_lookup:
  forall nm t, PoccTrm nm t ->
               forall p, weaklyClosed t p -> lookupDfn nm p <> None.
induction 1; intros p h1; unfold weaklyClosed in h1; apply h1;
try (solve [constructor; assumption]).
- apply PoLetInBod. assumption.
- apply PoAppA. assumption.
- apply PoAppR. assumption.
- apply PoCaseR. assumption.
Qed.

Lemma weaklyClosed_weaken:
  forall s p, weaklyClosed s p -> 
              forall t nm, weaklyClosed s ((nm, ecConstr t) :: p).
unfold weaklyClosed. intros s p h1 t nmx nmy h2.
assert (j1:= h1 _ h2). destruct (string_dec nmy nmx).
- rewrite e. unfold lookupDfn, lookupDfn. rewrite string_eq_bool_rfl.
  intros j2. discriminate.
- rewrite (lookupDfn_neq _ _ n). assumption.
Qed.

Lemma weaklyClosed_lookupDfn:
  forall nm p, weaklyClosed (TConst nm) p <-> lookupDfn nm p <> None.
unfold weaklyClosed; split.
- intros h1. apply h1. apply PoConst. rewrite string_eq_bool_rfl. reflexivity.
- intros h1 nmx h2. destruct (string_dec nmx nm).
  + subst. assumption. 
  + inversion_clear h2. rewrite (string_eq_bool_neq n) in H. discriminate.
Qed.

Lemma lookup_wclsd:
  forall nm p t, LookupDfn nm p t -> weaklyClosed (TConst nm) p.
induction 1; intros nm h; unfold weaklyClosed.
- inversion_clear h. simpl. rewrite H. intuition. discriminate.
- destruct (string_dec nm s1).
  + rewrite e. simpl. rewrite string_eq_bool_rfl. destruct t.
    intuition. discriminate.
  + simpl. rewrite (string_eq_bool_neq n). destruct t.
    unfold weaklyClosed in IHLookupDfn. apply (IHLookupDfn _ h).
Qed.

Inductive envOk : environ Term -> Prop :=
| envOk_nil : envOk nil
| envOk_cons : forall nm t p,
      fresh nm p -> envOk p -> weaklyClosed t p ->
         envOk ((nm, ecConstr t) :: p).
Hint Constructors envOk.

Lemma envOk_nPocc_hd:
  forall nmtp, envOk nmtp ->
  forall nm t p, nmtp = ((nm, ecConstr t) :: p) -> ~ PoccTrm nm t.
induction 1; intros nmx tx px h.
- discriminate.
- injection h. intros. subst. unfold weaklyClosed in H1. intros j.
  elim (H1 _ j). apply (proj1 (fresh_lookup_fails _ _) H).
Qed.

Lemma envOk_tl:
  forall nmtp, envOk nmtp ->
  forall nm t p, nmtp = ((nm, ecConstr t) :: p) -> envOk p.
induction 1; intros nmx tx px h.
- inversion h.
- injection h; intros. subst. auto.
Qed.

Lemma LookupEvnOk_nPocc:
  forall nm p t, LookupDfn nm p t -> envOk p -> ~ PoccTrm nm t.
induction 1; intros; intros h.
- inversion_Clear H. unfold weaklyClosed in H5. elim (H5 s). auto.
  apply (proj1 (fresh_lookup_fails _ _)). auto.
- elim IHLookupDfn; auto. destruct t. eapply (@envOk_tl _ H1 s1 t).
  reflexivity.
Qed.

(*********************** ??????
Lemma Crct_weaklyClosed:
  (forall p n t, Crct p n t -> weaklyClosed t p) /\
  (forall p n ts, Crcts p n ts -> weaklyCloseds ts p) /\
  (forall p n ds, CrctDs p n ds -> weaklyClosedd ds p).
apply CrctCrctsCrctDs_ind; unfold weaklyClosed; intros;
try (solve [inversion H|inversion H0|simpl;auto]).
- destruct (string_dec nm0 nm); unfold lookupDfn.
  + subst. rewrite (string_eq_bool_rfl nm). intros j. discriminate.
  + rewrite (string_eq_bool_neq n0). apply H0. assumption.
- inversion_clear H2.
- inversion_clear H1. apply H0. assumption.
- inversion_clear H1. apply H0. assumption.
- inversion_clear H3.
  + apply H0. assumption.
  + apply H2. assumption.
- inversion_clear H5. 
  + apply H0. assumption.
  + apply H2. assumption.
  + induction args. inversion_clear H6.
    * inversion_clear H6. destruct H4. unfold weaklyClosed in H4.
      apply (H4 nm H5). destruct H4. inversion_clear H3.
      apply IHargs; assumption.
- inversion H2. rewrite (string_eq_bool_eq _ _ H4). assumption.
- inversion H1.
- inversion_clear H3. 
  + apply (H0 nm). assumption.
  + induction brs; destruct H2; inversion_clear H4.
    * unfold weaklyClosed in H2. apply (H2 nm). assumption.
    * inversion_clear H1. eapply IHbrs; assumption.
- inversion_clear H1.
  induction ds; inversion_clear H2; inversion_clear H; destruct H0.
  + unfold weaklyClosed in H. eapply H. assumption.
  + apply IHds. simpl in H3. try assumption.
Qed.

Lemma Crct_envOk:
  (forall p n t, Crct p n t -> envOk p) /\
  (forall p n ts, Crcts p n ts -> envOk p) /\
  (forall p n ds, CrctDs p n ds -> envOk p).
apply CrctCrctsCrctDs_ind; intros; auto.
- constructor; auto. destruct (Crct_weaklyClosed). apply (H4 _ _ _ H1).
Qed.


Definition crct (p:environ Term) (t:Term) : Prop := envOk p /\ weaklyClosed t p.
Fixpoint crcts (p:environ Term) (ts:Terms) : Prop :=
  match ts with
    | tnil => True
    | tcons s ss => crct p s /\ crcts p ss
  end.

Goal forall p n t, Crct p n t -> crct p t.
intros p n t h. destruct Crct_envOk. destruct Crct_weaklyClosed; split.
- apply (H _ _ _ h).
- apply (H1 _ _ _ h).
Qed.

Lemma ok_lookup_nPocc:
  forall stp, envOk stp -> forall s t p, stp = ((s, ecConstr t) :: p) ->
                ~ PoccTrm s t.
induction 1; intros ss tt pp h.
- discriminate.
- injection h. intros. subst. unfold weaklyClosed in H1. intros j.
  elim (H1 _ j). apply (proj1 (fresh_lookup_fails _ _) H).
Qed.

Lemma weaklyClosed_nil_crct: forall t, weaklyClosed t nil -> crct nil t.
split; auto. 
Qed.

Lemma envOk_lookup_crct:
  forall p, envOk p -> forall nm t, LookupDfn nm p t -> crct p (TConst nm).
induction 1; intros xnm tx h1; inversion h1; subst; split; try intuition; 
unfold weaklyClosed; intros nmy h3; inversion_clear h3; simpl.
- rewrite H2. intuition. discriminate.
- rewrite (string_eq_bool_eq _ _ H2). rewrite (string_eq_bool_neq H7). 
  rewrite (proj2 (lookupDfn_LookupDfn _ _ _) H8). intuition. discriminate.
Qed.
***************)
***********************)
**********************************)