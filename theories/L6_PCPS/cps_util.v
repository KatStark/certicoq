(* Definitions of the L6 CPS intermediate representation.
 * Part of the CertiCoq project.
 *) 

From compcert.lib Require Import Coqlib.
From CertiCoq.L6 Require Import cps ctx Ensembles_util List_util
                                functions tactics map_util.
From Coq Require Import Arith.Arith NArith.BinNat Strings.String Lists.List
     omega.Omega Sets.Ensembles Relations.Relation_Operators Classes.Morphisms.
From MetaCoq.Template Require Import BasicAst. (* For identifier names *)

Import ListNotations.

Close Scope Z_scope.

Definition var_dec := M.elt_eq.

(** Lemmas about [findtag] *)
Lemma findtag_not_empty:
  forall A cl (k : A) (v : cTag), findtag cl v = Some k -> 0 < (length cl).
Proof.
  induction cl; intros.
  - inversion H.
  - simpl in H. destruct a. destruct (M.elt_eq c v).
    + inversion H. simpl. omega.
    + simpl. apply IHcl in H. omega.
Qed.

Lemma findtag_In_patterns {A} P c (v : A) :
  findtag P c = Some v ->
  List.In (c, v) P.
Proof.
  induction P as [ | [c' e'] P IHP]; intros H; try discriminate.
  simpl in H. edestruct (M.elt_eq c' c).
  - inv H. now left.
  - right. eauto.
Defined.
   
Lemma findtag_append_spec {A} c P P' (v : A) :
  findtag (P ++ P') c = Some v ->
  (findtag P c = Some v) \/
  (findtag P' c = Some v /\ forall v, ~ List.In (c, v) P).
Proof.
  induction P as [| [c' v'] P IHP]; intros H.
  - simpl in H. right; split; eauto.
  - simpl in *.
    destruct (M.elt_eq c' c); eauto.
    destruct (IHP H) as [H1 | [H1 H2]]; eauto.
    right; split; eauto. intros v''.
    intros Hc. inv Hc. inv H0; congruence.
    eapply H2; eauto.
Qed.

Lemma findtag_append_is_Some {A} c P P' (v : A) :
  findtag P c = Some v ->
  findtag (P ++ P') c = Some v.
Proof.
  induction P as [| [c' v'] P IHP]; simpl; intros H; eauto.
  - inv H.
  - destruct (M.elt_eq c' c); eauto.
Qed.

Lemma findtag_append_not_In {A} c (P P' : list (cTag * A)) :
  (forall v, ~ List.In (c, v) P) ->
  findtag (P ++ P') c = findtag P' c.
Proof.
  induction P as [| [c' v'] P IHP]; simpl; intros H; eauto.
  destruct (M.elt_eq c' c); eauto.
  - exfalso. subst. eapply H. left; eauto.
  - eapply IHP. intros x Hc. eapply H. eauto.
Qed.

Lemma findtag_In {A} (P : list (cTag * A)) c e :
  findtag P c = Some e -> List.In (c, e) P.
Proof.
  revert e. induction P as [| [c' e'] P IHp]; intros x H; try now inv H.
  simpl in H. inv H.
  destruct (M.elt_eq c' c); inv H1; try now constructor.
  constructor 2. now eapply IHp.
Qed.

Lemma Forall2_findtag {A B} c Pats1 Pats2 (e : A) (P : A -> B  -> Prop) :
  findtag Pats1 c = Some e ->
  Forall2 (fun ce1 ce2 =>
             let '(c1, e1) := ce1 in
             let '(c2, e2) := ce2 in
             c1 = c2 /\ P e1 e2) Pats1 Pats2 ->
  exists e', findtag Pats2 c = Some e' /\ P e e'.
Proof.
  intros Hf Hall. revert e Hf. induction Hall; intros e Hf.
  - inv Hf.
  - destruct x as [c1 e1]. destruct y as [c2 e2]. simpl in *.
    destruct H as [Heq1 HP]; subst.
    destruct (M.elt_eq c2 c); eauto. inv Hf.
    eexists; split; eauto. 
Qed. 


(** [split_fds B1 B2 B] iff B is an interleaving of the definitions in B1 and B2 *)
Inductive split_fds: fundefs -> fundefs -> fundefs -> Prop :=
| Left_f:
    forall lfds rfds lrfds v t ys e,
      split_fds lfds rfds lrfds ->
      split_fds (Fcons v t ys e lfds) rfds (Fcons v t ys e lrfds)
| Right_f:
    forall lfds rfds lrfds v t ys e,
      split_fds lfds rfds lrfds ->
      split_fds lfds (Fcons v t ys e rfds) (Fcons v t ys e lrfds)
| End_f: split_fds Fnil Fnil Fnil.

(** Lemmas about [split_fds]. *)
Lemma split_fds_nil_l fdefs : split_fds fdefs Fnil fdefs.
  induction fdefs; constructor; eauto.
Qed.

Lemma split_fds_nil_r fdefs : split_fds Fnil fdefs fdefs.
  induction fdefs; constructor; eauto.
Qed.

Lemma split_fds_trans B1 B2 B3 B1' B2' :
  split_fds B1 B1' B2 ->
  split_fds B2 B2' B3 ->
  exists B2,
    split_fds B1' B2' B2 /\ split_fds B1 B2 B3.
Proof.
  intros Hs1 Hs2. revert B1 B1' Hs1. induction Hs2; intros B1 B1' Hs1.
  - inv Hs1. 
    edestruct IHHs2 as [B2'' [Hs3 Hs4]]; eauto.
    eexists. split; eauto. constructor; eauto.
    edestruct IHHs2 as [B2'' [Hs3 Hs4]]; eauto.
    eexists. split; constructor; eauto.
  - edestruct IHHs2 as [B2'' [Hs3 Hs4]]; eauto.
    eexists. split; constructor; eauto.
  - eexists; split; eauto using split_fds_nil_l.
Qed.  

Lemma split_fds_sym B1 B2 B3 :
  split_fds B1 B2 B3 ->
  split_fds B2 B1 B3.
Proof.
  intros Hs1. induction Hs1; now constructor; eauto.
Qed.

Lemma split_fds_Fnil B1 B2 :
  split_fds B1 B2 Fnil ->
  B1 = Fnil /\ B2 = Fnil.
Proof.
  intros H. inv H; eauto.
Qed.

Lemma split_fds_Fcons_l B1 B2 B3 :
  split_fds B1 B2 B3 ->
  B1 <> Fnil -> B3 <> Fnil.
Proof.
  intros H1 H2. inv H1; eauto; congruence.
Qed.

Lemma split_fds_Fcons_r B1 B2 B3 :
  split_fds B1 B2 B3 ->
  B2 <> Fnil -> B3 <> Fnil.
Proof.
  intros H1 H2. inv H1; eauto; congruence.
Qed.


Lemma split_fds_Fnil_eq_l B1 B2 :
  split_fds Fnil B1 B2 -> B1 = B2.
Proof.
  revert B1. induction B2; intros B1 H; auto; inv H; f_equal; eauto.
Qed.

Lemma split_fds_Fnil_eq_r B1 B2 :
  split_fds B1 Fnil B2 -> B1 = B2.
Proof.
  revert B1. induction B2; intros B1 H; auto; inv H; f_equal; eauto.
Qed.

(** Append function definitions *)
Fixpoint fundefs_append (B1 B2 : fundefs) : fundefs :=
  match B1 with
    | Fcons f t xs xe B => Fcons f t xs xe (fundefs_append B B2)
    | Fnil => B2
  end.

(** Lemmas about [fundefs_append] *)
Lemma def_funs_append B B1 B2 rho rho' :
  def_funs B (fundefs_append B1 B2) rho rho' =
  def_funs B B1 rho (def_funs B B2 rho rho').
Proof.
  induction B1; simpl; eauto. now rewrite IHB1.
Qed.

Lemma find_def_fundefs_append_r f B1 B2 v:
  find_def f B2 = Some v ->
  find_def f B1 = None ->
  find_def f (fundefs_append B1 B2) = find_def f B2.
Proof.
  induction B1; simpl; intros H1 H2; eauto.
  destruct (M.elt_eq f v0); try discriminate; eauto.
Qed.

Lemma find_def_fundefs_append_l f B1 B2 v:
  find_def f B1 = Some v ->
  find_def f (fundefs_append B1 B2) = find_def f B1.
Proof.
  induction B1; simpl; intros H2; eauto; try discriminate.
  destruct (M.elt_eq f v0); try discriminate; eauto.
Qed.

Lemma fundefs_append_split_fds B1 B2 B3 :
  fundefs_append B1 B2 = B3 ->
  split_fds B1 B2 B3.
Proof.
  revert B1. induction B3; intros B1 Hdefs.
  - destruct B1; simpl in Hdefs; subst. inv Hdefs.
    constructor. eauto.
    eapply split_fds_nil_r.
  - destruct B1; simpl in Hdefs; try congruence. subst.
    constructor.
Qed.

Lemma find_def_fundefs_append_Fcons_neq f v t ys e B1 B2 :
  f <> v ->
  find_def f (fundefs_append B1 (Fcons v t ys e B2)) =
  find_def f (fundefs_append B1 B2).
Proof.
  intros Hneq. revert B2. induction B1; intros B2.
  - simpl. destruct (M.elt_eq f v0); eauto.
  - simpl. destruct (M.elt_eq f v); try contradiction; eauto.
Qed.

Lemma split_fds_cons_l_append_fundefs f tau xs e B1 B2 B3 : 
  split_fds (Fcons f tau xs e B1) B2 B3 ->
  exists B1' B2',
    B3 = fundefs_append B1' (Fcons f tau xs e B2') /\
    split_fds B1 B2 (fundefs_append B1' B2').
Proof.
  revert B1 B2. induction B3; intros B1 B2 Hspl.
  - inv Hspl.
    + exists Fnil, B3; eauto.
    + edestruct IHB3 as [B1' [B2' [Heq Hspl]]]; eauto.
      exists (Fcons v f0 l e0 B1'), B2'. rewrite Heq; split; eauto.
      simpl; constructor; eauto.
  - inv Hspl.
Qed.

Lemma split_fds_cons_r_append_fundefs f tau xs e B1 B2 B3 : 
  split_fds B1 (Fcons f tau xs e B2) B3 ->
  exists B1' B2',
    B3 = fundefs_append B1' (Fcons f tau xs e B2') /\
    split_fds B1 B2 (fundefs_append B1' B2').
Proof.
  revert B1 B2. induction B3; intros B1 B2 Hspl.
  - inv Hspl.
    + edestruct IHB3 as [B1' [B2' [Heq Hspl]]]; eauto.
      exists (Fcons v f0 l e0 B1'), B2'. rewrite Heq; eauto. split; eauto.
      simpl. constructor; eauto.
    + exists Fnil, B3; eauto.
  - inv Hspl.
Qed.

(** Lemmas about [getlist] *)
Lemma getlist_In {A} (rho : M.t A) ys x vs :
  getlist ys rho = Some vs ->
  List.In x ys ->
  exists v, M.get x rho = Some v.
Proof.
  revert x vs. induction ys; intros x vs Hget H. inv H.
  inv H; simpl in Hget.
  - destruct (M.get x rho) eqn:Heq; try discriminate; eauto.
  - destruct (M.get a rho) eqn:Heq; try discriminate; eauto.
    destruct (getlist ys rho) eqn:Heq'; try discriminate; eauto.
Qed.

Lemma In_getlist {A} (xs : list var) (rho : M.t A) :
  (forall x, List.In x xs -> exists v, M.get x rho = Some v) ->
  exists vs, getlist xs rho = Some vs. 
Proof.                                            
  intros H. induction xs. 
  - eexists; simpl; eauto.
  - edestruct IHxs. 
    + intros x Hin. eapply H. now constructor 2. 
    + edestruct H. now constructor. 
      eexists. simpl. erewrite H1, H0. 
      reflexivity. 
Qed.

Lemma getlist_nth_get {A} (xs : list var) (vs : list A) rho (x : var) N :
  getlist xs rho = Some vs ->
  nthN xs N = Some x ->
  exists v, nthN vs N = Some v /\ M.get x rho = Some v. 
Proof.
  revert vs N; induction xs; intros vs N Hget Hnth.
  - inv Hnth. 
  - simpl in Hget.
    destruct (M.get a rho) eqn:Hget'; try discriminate.
    destruct (getlist xs rho) eqn:Hgetlist'; try discriminate.
    inv Hget. destruct N. 
    + inv Hnth. eexists; simpl; eauto.
    + edestruct IHxs as [v' [Hnth1 Hget1]]; eauto. 
Qed.

Lemma getlist_set_neq {A} xs x (v : A) rho :
  ~ List.In x xs ->
  getlist xs (M.set x v rho) = getlist xs rho. 
Proof.
  intros Hin.
  revert rho. induction xs; intros rho.
  - reflexivity.
  - simpl. rewrite M.gso.
    + rewrite IHxs. reflexivity.
      intros Hin'. eapply Hin. now constructor 2.
    + intros Heq; subst. eapply Hin. now constructor.
Qed.

Lemma getlist_setlist {A} xs (vs : list A) rho rho' :
  NoDup xs ->
  setlist xs vs rho = Some rho' ->
  getlist xs rho' = Some vs.
Proof.
  revert rho' vs; induction xs; intros rho' vs Hnd Hset.
  - inv Hset. destruct vs; try discriminate. reflexivity.
  - inv Hnd. simpl in *.
    destruct vs; try discriminate.
    destruct (setlist xs vs rho) eqn:Hset'; try discriminate. inv Hset.
    rewrite M.gss. rewrite getlist_set_neq.
    now erewrite IHxs; eauto. eassumption.
Qed.

Lemma getlist_setlist_Disjoint {A} xs xs' (vs : list A) rho rho' :
  Disjoint _ (FromList xs) (FromList xs') ->
  setlist xs vs rho = Some rho' ->
  getlist xs' rho' = getlist xs' rho.
Proof with now eauto with Ensembles_DB.
  revert rho' vs; induction xs; intros rho' vs Hd Hset.
  - inv Hset. destruct vs; try discriminate. inv H0; reflexivity.
  - simpl in *.
    destruct vs; try discriminate.
    destruct (setlist xs vs rho) eqn:Hset'; try discriminate. inv Hset.
    rewrite FromList_cons in Hd.
    rewrite getlist_set_neq.
    erewrite IHxs...
    intros Hc; eapply Hd. constructor; eauto.
Qed.

Lemma getlist_reset {A} σ x y (v : A) rho l :
  M.get (σ x) rho = Some v ->
  ~ In _ (image σ (Setminus _ (FromList l) (Singleton _ x))) y ->
  getlist (map σ l) rho = getlist (map (σ { x ~> y }) l) (M.set y v rho).
Proof with now eauto with Ensembles_DB.
  intros Hget Hnin. induction l; eauto.
  simpl. destruct (peq x a); subst.
  - rewrite extend_gss, M.gss, Hget.
    rewrite IHl. reflexivity.
    intros Hc. eapply Hnin.
    rewrite FromList_cons.
    eapply image_monotonic; try eassumption...      
  - rewrite extend_gso; eauto.
    rewrite M.gso.
    rewrite IHl. reflexivity.
    intros Hc. eapply Hnin.
    rewrite FromList_cons.
    eapply image_monotonic; try eassumption...
    intros Hc. eapply Hnin.
    subst. rewrite FromList_cons. eexists; split; eauto.
    constructor; eauto.
    intros Hc; inv Hc. congruence.
Qed.

Lemma getlist_reset_neq {A} σ x y (v : A) rho l :
  ~ In _ (image σ (Setminus _ (FromList l) (Singleton _ x))) y ->
  ~ List.In x l -> 
  getlist (map σ l) rho = getlist (map (σ { x ~> y }) l) (M.set y v rho).
Proof with now eauto with Ensembles_DB.
  intros  Hnin. induction l; intros Hnin'; eauto.
  simpl. destruct (peq x a); subst.
  - exfalso. eapply Hnin'. now constructor.
  - rewrite extend_gso; eauto.
    rewrite M.gso.
    rewrite IHl. reflexivity.
    intros Hc. eapply Hnin.
    rewrite FromList_cons.
    eapply image_monotonic; try eassumption...
    intros Hc. eapply Hnin'. now constructor 2.
    intros Hc. subst. eapply Hnin.
    rewrite FromList_cons. eexists; split; eauto.
    constructor; eauto.
    intros Hc; inv Hc. congruence.
Qed.

Lemma get_eq_getlist_eq {A} (rho rho' : M.t A) xs :
  (forall z, M.get z rho = M.get z rho') ->
  getlist xs rho = getlist xs rho'.
Proof.
  induction xs; intros H; eauto.
  simpl; f_equal.
  rewrite IHxs; eauto.
  rewrite H. reflexivity.
Qed.

Lemma getlist_app {A} m l1 l2 (v1 v2 : list A) :
  getlist l1 m = Some v1 ->
  getlist l2 m = Some v2 ->
  getlist (l1 ++ l2) m = Some (v1 ++ v2).
Proof.
  revert v1. induction l1; intros v1 Hget1 Hget2; simpl in *.
  - inv Hget1. eauto.
  - destruct (M.get a m) eqn:Hgeta; try discriminate.
    destruct (getlist l1 m) eqn:Hget; try discriminate.
    inv Hget1. simpl. erewrite IHl1; eauto.
Qed.

Lemma getlist_length_eq {A} l (vs : list A) rho : 
  getlist l rho = Some vs ->
  length l = length vs.
Proof.
  revert vs; induction l; intros vs Hget.
  - inv Hget. eauto.
  - simpl in Hget. destruct (M.get a rho); try discriminate.
    destruct (getlist l rho); try discriminate.
    inv Hget. simpl. f_equal; eauto.
Qed.

Lemma app_getlist {A} l1 l2 (vs : list A) rho :
  getlist (l1 ++ l2) rho = Some vs ->
  exists vs1 vs2,
    getlist l1 rho = Some vs1 /\
    getlist l2 rho = Some vs2 /\
    vs = vs1 ++ vs2.
Proof.
  revert vs. induction l1; intros vs Hget.
  - simpl in Hget. repeat eexists; eauto.
  - simpl in Hget.
    destruct (M.get a rho) eqn:Hgeta; try discriminate.
    destruct (getlist (l1 ++ l2) rho) eqn:Hgetl; try discriminate.
    inv Hget.
    edestruct IHl1 as [vs1 [vs2 [Hget1 [Hget2 Heq]]]].
    reflexivity.
    repeat eexists; eauto. simpl.
    rewrite Hgeta, Hget1. reflexivity.
    simpl. congruence.
Qed.

Lemma getlist_In_val {A} (rho : M.t A) ys v vs :
  getlist ys rho = Some vs ->
  List.In v vs ->
  exists x, List.In x ys /\ M.get x rho = Some v.
Proof.
  revert v vs. induction ys; intros x vs Hget H.
  - inv Hget. now inv H.
  - simpl in *.
    destruct (M.get a rho) eqn:Heq; try discriminate; eauto.
    destruct (getlist ys rho) eqn:Heq'; try discriminate; eauto.
    inv Hget. inv H; eauto.
    edestruct IHys as [y [Hin Hget]]; eauto.
Qed.


(** Lemmas about [setlist]  *)

Lemma setlist_Forall2_get {A} (P : A -> A -> Prop)
      xs vs1 vs2 rho1 rho2 rho1' rho2' x : 
  Forall2 P vs1 vs2 ->
  setlist xs vs1 rho1 = Some rho1' ->
  setlist xs vs2 rho2 = Some rho2' ->
  List.In x xs ->
  exists v1 v2,
    M.get x rho1' = Some v1 /\
    M.get x rho2' = Some v2 /\ P v1 v2.
Proof.
  revert rho1' rho2' vs1 vs2.
  induction xs; simpl; intros rho1' rho2' vs1 vs2 Hall Hset1 Hset2 Hin.
  - inv Hin.
  - destruct (Coqlib.peq a x); subst.
    + destruct vs1; destruct vs2; try discriminate.
      destruct (setlist xs vs1 rho1) eqn:Heq1;
        destruct (setlist xs vs2 rho2) eqn:Heq2; try discriminate.
      inv Hset1; inv Hset2. inv Hall.
      repeat eexists; try rewrite M.gss; eauto.
    + destruct vs1; destruct vs2; try discriminate.
      destruct (setlist xs vs1 rho1) eqn:Heq1;
        destruct (setlist xs vs2 rho2) eqn:Heq2; try discriminate.
      inv Hset1; inv Hset2. inv Hall. inv Hin; try congruence.
      edestruct IHxs as [v1 [v2 [Hget1 [Hget2 HP]]]]; eauto.
      repeat eexists; eauto; rewrite M.gso; eauto.
Qed.

Lemma get_setlist_In_xs {A} x xs vs rho rho' :
  In var (FromList xs) x ->
  setlist xs vs rho = Some rho' ->
  exists v : A, M.get x rho' = Some v.
Proof.
  revert rho rho' vs. induction xs; intros rho rho' vs Hin Hset.
  - rewrite FromList_nil in Hin. exfalso.
    eapply not_In_Empty_set. eassumption. 
  - rewrite FromList_cons in Hin.
    destruct vs; try discriminate.    
    simpl in Hset. destruct (setlist xs vs rho) eqn:Hsetlist; try discriminate.
    inv Hset. inv Hin.
    + inv H. eexists. rewrite M.gss. reflexivity.
    + destruct (Coqlib.peq x a); subst.
      * eexists. now rewrite M.gss.
      * edestruct IHxs; eauto.
        eexists. simpl. rewrite M.gso; eauto. 
Qed.

Lemma setlist_not_In {A} (xs : list var) (vs : list A)
      (rho rho' : M.t A) (x : var) :
  setlist xs vs rho = Some rho' ->
  ~ List.In x xs ->
  M.get x rho = M.get x rho'.
Proof.
  revert vs rho'.
  induction xs; simpl; intros vs rho' Hset Hin.
  - destruct vs; congruence.
  - destruct vs; try discriminate.
    destruct (setlist xs vs rho) eqn:Heq1; try discriminate. inv Hset.
    rewrite M.gso; eauto.
Qed.

Lemma setlist_length {A} (rho rho' rho1 : M.t A)
      (xs : list var) (vs1 vs2 : list A) :
  length vs1 = length vs2 -> 
  setlist xs vs1 rho = Some rho1 ->
  exists rho2, setlist xs vs2 rho' = Some rho2.
Proof.
  revert vs1 vs2 rho1.
  induction xs as [| x xs IHxs ]; intros vs1 vs2 rho1 Hlen Hset.
  - inv Hset. destruct vs1; try discriminate. inv H0.
    destruct vs2; try discriminate. eexists; simpl; eauto. 
  - destruct vs1; try discriminate. destruct vs2; try discriminate.
    inv Hlen. simpl in Hset. 
    destruct (setlist xs vs1 rho) eqn:Heq2; try discriminate.
    edestruct (IHxs _ _ _ H0 Heq2) as  [vs2' Hset2].
    eexists. simpl; rewrite Hset2; eauto.
Qed.

Lemma set_permut {A} rho x y (v1 v2 : A) z :
  x <> y ->
  M.get z (M.set x v1 (M.set y v2 rho)) =
  M.get z (M.set y v2 (M.set x v1 rho)).
Proof.
  intros Hnin. destruct (peq z x); subst.
  - rewrite M.gss, M.gso, M.gss; eauto.
  - rewrite (@M.gso _ z x); eauto.
    destruct (peq z y); subst.
    + rewrite !M.gss; eauto.
    + rewrite !M.gso; eauto.
Qed.

Lemma set_setlist_permut {A} rho rho' y ys (v : A) vs :
  setlist ys vs rho = Some rho' ->
  ~ List.In y ys ->
  exists rho'',
    setlist ys vs (M.set y v rho) = Some rho'' /\
    (forall z, M.get z (M.set y v rho') = M.get z rho'').
Proof.
  revert vs rho'.
  induction ys; intros vs rho' Hset Hin;
  destruct vs; try discriminate.
  - inv Hset. eexists; split; simpl; eauto.
  - simpl in Hset.
    destruct (setlist ys vs rho) eqn:Heq; try discriminate.
    inv Hset. edestruct IHys as [rho'' [Hset Hget]]; eauto.
    intros Hc; eapply Hin; now constructor 2.
    eexists; split.
    simpl. rewrite Hset. reflexivity.
    intros z. rewrite set_permut.
    destruct (peq z a); subst.
    + rewrite !M.gss; eauto.
    + rewrite !(@M.gso _ z a); eauto.
    + intros Hc. eapply Hin.
      constructor; eauto.
Qed.

Lemma setlist_length3 {A} (rho : M.t A) xs vs : 
  length xs = length vs ->
  exists rho', setlist xs vs rho = Some rho'.
Proof.
  revert vs; induction xs; intros vs Hlen; destruct vs; try discriminate.
  - eexists; simpl; eauto.
  - inv Hlen.
    edestruct IHxs as [rho' Hset]. eassumption.
    eexists. simpl. rewrite Hset. reflexivity.
Qed.

Lemma setlist_app {A} xs1 xs2 (vs1 vs2 : list A) rho rho' : 
  setlist (xs1 ++ xs2) (vs1 ++ vs2) rho = Some rho' ->
  length xs1 = length vs1 ->
  exists rho'',
    setlist xs2 vs2 rho = Some rho'' /\
    setlist xs1 vs1 rho'' = Some rho'.
Proof.
  revert vs1 rho'. induction xs1; intros vs1 rho' Hset Hlen.
  - destruct vs1; try discriminate.
    eexists; split; eauto.
  - destruct vs1; try discriminate.
    inv Hlen. simpl in Hset.
    destruct (setlist (xs1 ++ xs2) (vs1 ++ vs2) rho) eqn:Heq; try discriminate.
    inv Hset. edestruct IHxs1 as [rho'' [Hset1 Hset2]].
    eassumption. eassumption.
    eexists. split. eassumption. simpl; rewrite Hset2; reflexivity.
Qed.


Lemma setlist_length_eq {A} rho rho' xs (vs : list A) :
  setlist xs vs rho = Some rho' ->
  length xs = length vs.
Proof.
  revert rho' vs; induction xs; intros rho' vs Hset.
  - destruct vs; try discriminate. reflexivity.
  - destruct vs; try discriminate.
    simpl in Hset.
    destruct (setlist xs vs rho) eqn:Heq; try discriminate.
    simpl. f_equal. inv Hset. eauto.
Qed.

Lemma getlist_reset_lst {A} σ xs ys (vs : list A) rho rho' l  : 
  setlist ys vs rho = Some rho' ->
  getlist (map σ xs) rho = Some vs ->
  Disjoint _ (image σ (FromList l)) (FromList ys) ->
  length xs = length ys ->
  NoDup xs -> NoDup ys ->
  getlist (map σ l) rho = getlist (map (σ <{ xs ~> ys }>) l) rho'.
Proof with now eauto with Ensembles_DB.
  revert σ ys vs rho' rho. induction xs as [| x xs IHxs ];
    intros σ ys vs rho' rho Hset Hget HD Hlen Hnd1 Hnd2.
  - destruct ys; try discriminate.
    inv Hget. inv Hset. reflexivity.
  - destruct ys; try discriminate. simpl in *.
    inv Hlen. destruct vs as [| v vs]; try discriminate.
    destruct (setlist ys vs rho) eqn:Hset'; try discriminate.
    destruct (M.get (σ x) rho) eqn:Hget'; try discriminate.
    destruct (getlist (map σ xs) rho) eqn:Hgetl; try discriminate.
    inv Hget. inv Hset. inv Hnd1. inv Hnd2. rewrite !FromList_cons in HD.
    assert (H : getlist (map ((σ <{ xs ~> ys }>) {x ~> e}) l) (M.set e v t) =
                getlist (map ((σ <{ xs ~> ys }>)) l) t).
    { destruct (in_dec peq x l).
      - rewrite <- getlist_reset; try reflexivity.
        rewrite extend_lst_gso; eauto.
        erewrite <- setlist_not_In. eassumption. eassumption.
        intros Hc. eapply HD. constructor; eauto.
        eexists; split; eauto. 
        intros Hc.
        apply image_extend_lst_Included in Hc; eauto.
        inv Hc; eauto. eapply HD. constructor; eauto.
        eapply image_monotonic; [| eassumption ]...
      - rewrite map_extend_not_In; eauto.
        erewrite getlist_set_neq. reflexivity.
        intros Hc. eapply in_map_iff in Hc.
        destruct Hc as [x' [Heq Hin]]. 
        destruct (in_dec peq x' xs).
        + edestruct (extend_lst_gss σ) as [y' [Hin' Heq']]; eauto.
          rewrite Heq in Hin'. subst.
          subst. eauto.
        + rewrite extend_lst_gso in Heq; eauto.
          eapply HD. constructor; eauto.
          eexists; eauto. }
    rewrite H.
    erewrite <- IHxs; eauto.
    now eauto with Ensembles_DB.
Qed.


(** A case statement only pattern matches constructors from the same inductive type *)
Inductive caseConsistent cenv : list (cTag * exp) -> cTag -> Prop :=
| CCnil  :
    forall (t : cTag),
      caseConsistent cenv nil t
| CCcons :
    forall (a a' b b':name) (l : list (cTag * exp)) (t t' : cTag) (ty ty' : iTag)
      (n n' : N) (i i' : N) (e : exp),
      M.get t cenv  = Some (a, b, ty, n, i) ->
      M.get t' cenv = Some (a', b', ty', n', i') ->
      ty = ty' ->
      caseConsistent cenv l t ->
      caseConsistent cenv ((t', e) :: l) t.
  
Fixpoint caseConsistent_f (cenv  : cEnv) (l:list (cTag * exp)) (t:cTag): bool :=
  match l with
  | nil => true
  | (t', e)::l' =>
    caseConsistent_f cenv l' t &&
    match (M.get t cenv) with
    | Some (a, _, ty, n, i) =>
      (match (M.get t' cenv) with
       | Some (a', _, ty', n', i') =>
         Pos.eqb ty  ty'
       | _ => false
       end)
    | _ => false
    end
  end.


Theorem caseConsistent_c cenv:
  forall l t,
    caseConsistent cenv l t <-> caseConsistent_f cenv l t = true.
Proof.
  induction l; split; intros.
  - reflexivity.
  - constructor.
  - inv H. simpl.
    setoid_rewrite H2. setoid_rewrite H3.
    apply andb_true_iff.
    split.
    apply IHl; auto.
    apply Pos.eqb_refl. 
  - simpl in H. simpl. 
    destruct a.
    inv H. 
    edestruct andb_prop as [Ha1 Ha2]. eassumption. 
    destruct (M.get t cenv) as [ [[[[? ?] ?] ?] ?] | ] eqn:tc; setoid_rewrite tc in Ha2; try congruence.
      destruct (M.get c cenv) as [ [[[[? ?] ?] ?] ?] | ] eqn:tc'; setoid_rewrite tc' in Ha2; try congruence.
      econstructor; eauto. apply Peqb_true_eq in Ha2. auto. apply IHl. auto.
Qed.


(** Lemmas about case consistent *)

Lemma caseConsistent_same_cTags cenv P1 P2 t :
  Forall2 (fun pat pat' => fst pat = fst pat') P1 P2 ->
  caseConsistent cenv P1 t ->
  caseConsistent cenv P2 t.
Proof.
  intros H Hc; induction H.
  - now constructor. 
  - inv Hc. destruct y as [t'' e'']. simpl in *. subst.
    econstructor; now eauto.
Qed.

(** ** Existance (or not) of a binding in a map -- TODO : maybe move the a map_util.v? *)

(** The variables in S are defined in the map. *)
Definition binding_in_map {A} (S : Ensemble M.elt) (map : M.t A) : Prop :=
  forall x, In _ S x -> exists v, M.get x map = Some v. 

(** The variables in S are not defined in the map. *)
Definition binding_not_in_map {A} (S : Ensemble M.elt) (map : M.t A) := 
  forall x : M.elt, In M.elt S x -> M.get x map = None.


(** * Lemmas about [binding_in_map] *)

Instance Proper_binding_in_map (A : Type) : Proper (Same_set _ ==> eq ==> iff) (@binding_in_map A). 
Proof.
  intros s1 s2 Hseq x1 x2 Heq; subst; split; intros Hbin x Hin;
    eapply Hbin; eapply Hseq; eauto.
Qed.


Lemma binding_in_map_Union {A} S1 S2 (rho : M.t A) :
  binding_in_map S1 rho ->
  binding_in_map S2 rho ->
  binding_in_map (S1 :|: S2) rho.
Proof.
  intros Hin1 Hin2 x Hin. inv Hin; eauto.
Qed.

Lemma binding_in_map_Singleton {A}  (rho : M.t A) x v :
  M.get x rho = Some v ->
  binding_in_map [set x] rho.
Proof.
  intros Hget; intros v2 Heq. inv Heq. eexists; eauto.
Qed.

(** [binding_in_map] is anti-monotonic on its first argument *)
Lemma binding_in_map_antimon {A} S S' (rho : M.t A) :
  Included _ S' S ->
  binding_in_map S rho ->
  binding_in_map S' rho.
Proof.
  intros Hin Hv x Hs. eauto.
Qed.

(** Extend the environment with a variable and put it in the set *)
Lemma binding_in_map_set {A} x (v : A) S rho :
  binding_in_map S rho ->
  binding_in_map (Union _ S (Singleton _ x)) (M.set x v rho).
Proof. 
  intros H x' Hs. inv Hs.
  - edestruct H; eauto.
    destruct (Coqlib.peq x' x) eqn:Heq'.
    + eexists. simpl. now rewrite M.gsspec, Heq'.
    + eexists. simpl. rewrite M.gsspec, Heq'.
      eassumption.
  - inv H0. eexists. rewrite M.gss. eauto.
Qed.

(** Extend the environment with a list of variables and put them in the set *)
Lemma binding_in_map_setlist {A : Type} xs vs S (rho rho' : M.t A) :
  binding_in_map S rho ->
  setlist xs vs rho = Some rho' ->
  binding_in_map (Union _ (FromList xs) S) rho'.
Proof.
  intros H Hset x' Hs.
  destruct (Decidable_FromList xs). destruct (Dec x').
  - eapply get_setlist_In_xs; eauto.
  - destruct Hs; try contradiction. 
    edestruct H; eauto.
    eexists. erewrite <- setlist_not_In; eauto.
Qed.

Lemma binding_not_in_map_antimon (A : Type) (S S' : Ensemble M.elt) (rho : M.t A):
  Included M.elt S' S -> binding_not_in_map S rho -> binding_not_in_map S' rho.
Proof. 
  intros Hin Hb x Hin'. eauto.
Qed.

Lemma binding_not_in_map_set_not_In_S {A} S map x (v : A) :
  binding_not_in_map S map ->
  ~ In _ S x ->
  binding_not_in_map S (M.set x v map). 
Proof. 
  intros HB Hnin x' Hin.
  rewrite M.gsspec. destruct (Coqlib.peq x' x); subst; try contradiction. 
  eauto. 
Qed.

Lemma binding_in_map_Included {A} S (rho : M.t A) :
  binding_in_map S rho ->
  Included _ S (FromList (List.map fst (M.elements rho))).
Proof.
  intros Hin x Hx. unfold FromList, In.
  eapply in_map_iff. edestruct Hin as [v Hget]; eauto.
  eexists (x, v). split; eauto.
  eapply M.elements_correct. eassumption.
Qed.


Lemma binding_in_map_getlist {A} S m  xs :
  binding_in_map S m ->
  Included _  (FromList xs) S ->
  exists (vs : list A), getlist xs m = Some vs.
Proof with now eauto with Ensembles_DB.
  intros Hin Hinc. induction xs.
  - eexists; simpl; eauto.
  - rewrite FromList_cons in Hinc. edestruct Hin with (x := a) as [v' Hget].
    now eapply Hinc; eauto.
    edestruct IHxs as [vs' Hgetl].
    eapply Included_trans...
    eexists; simpl. rewrite Hget, Hgetl. reflexivity.
Qed.

Lemma binding_in_map_key_set {A} (rho : M.t A) : 
  binding_in_map (key_set rho) rho.
Proof.
  unfold binding_in_map. intros x Hget.
  unfold key_set, In in *.
  destruct (M.get x rho); eauto.
  exfalso; eauto.
Qed.

Inductive dsubterm_e:exp -> exp -> Prop :=
| dsubterm_constr :
    forall x t ys e, dsubterm_e e (Econstr x t ys e)
| dsubterm_proj :
    forall v t n y e, dsubterm_e e (Eproj v t n y e)
| dsubterm_prim :
    forall x p ys e, dsubterm_e e (Eprim x p ys e)
| dsubterm_case :
    forall x e g cl, List.In (g, e) cl -> dsubterm_e e (Ecase x cl)
| dsubterm_fds :
    forall e' fds e,
      dsubterm_fds_e e' fds -> dsubterm_e e' (Efun fds e)
| dsubterm_fds2:
    forall fds e,
      dsubterm_e e (Efun fds e)
with dsubterm_fds_e: exp -> fundefs -> Prop :=
     | dsubterm_cons:
         forall e f t ys fds', dsubterm_fds_e e (Fcons f t ys e fds')
     | dsubterm_cons_fds:
         forall e' fds' f t ys e , dsubterm_fds_e e' fds' -> dsubterm_fds_e e' (Fcons f t ys e fds').

Definition subterm_e := clos_trans _ dsubterm_e.
Definition subterm_or_eq := clos_refl_trans _ dsubterm_e.

Inductive subterm_fds_e: exp -> fundefs -> Prop :=
| subterm_cons:
    forall e e' f t ys fds', subterm_e e' e -> subterm_fds_e e' (Fcons f t ys e fds')
| subterm_cons_fds:
    forall e' fds' f t ys e , subterm_fds_e e' fds' -> subterm_fds_e e' (Fcons f t ys e fds').


Inductive subfds_fds: fundefs -> fundefs -> Prop :=
| subfds_cons':
    forall fds' fds f t ys e,
      subfds_fds fds' fds ->
      subfds_fds fds' (Fcons f t ys e fds)
| subfds_cons:
    forall fds f t ys e, subfds_fds fds (Fcons f t ys e fds).

Definition subfds_or_eq: fundefs -> fundefs -> Prop :=
  fun fds' fds => subfds_fds fds' fds \/ fds' = fds.

Definition subfds_e: fundefs -> exp -> Prop := 
  fun fds  e =>
    exists fds' e', subterm_or_eq (Efun fds' e') e /\  subfds_or_eq fds fds'.


Theorem subfds_rebase:
  forall fds v f l e fds', 
    subfds_fds (Fcons v f l e fds) fds' ->
    subfds_fds fds fds'.
Proof.
  induction fds'; intros.
  inv H.
  apply IHfds' in H2. constructor. auto.
  constructor. constructor 2.
  inv H.
Qed.

Theorem subfds_trans:
  forall fds' fds fds'',
    subfds_fds fds fds' -> subfds_fds fds' fds'' -> subfds_fds fds fds''.
Proof.
  induction fds'; intros.
  - inv H.
    apply subfds_rebase in H0. eapply IHfds'; eauto.
    apply subfds_rebase in H0. auto.
  - inv H.
Qed.
    
Theorem subfds_or_eq_left:
  forall fds' fds fds'',
    subfds_fds fds fds' -> subfds_or_eq fds' fds'' -> subfds_or_eq fds fds''.
Proof.
  intros. inv H0.
  - left. eapply subfds_trans; eauto. 
  - left. auto.
Qed.

Theorem subfds_e_subfds:
  forall fds e fds', subfds_fds fds' fds -> subfds_e fds e -> subfds_e fds' e.
Proof.
  destruct fds; intros.
  - destruct H0; destructAll. exists x. exists x0. split.
    assumption.  eapply subfds_or_eq_left. apply H. assumption.
  - inversion H. 
Qed.

(** Number of function definitions *)
Fixpoint numOf_fundefs (B : fundefs) : nat := 
  match B with
  | Fcons _ _ xs e B =>
    1 + numOf_fundefs B
  | Fnil => 0
  end.

Definition num_occur_list (lv:list var) (v:var) : nat :=
  fold_right (fun v' n => if (var_dec v v') then 1 + n
                       else n) 0 lv.

(* number of time var occurs in exp (free or not)*)
Inductive num_occur: exp -> var -> nat -> Prop :=
| Num_occ_constr:
  forall x t ys e v n,
    num_occur e v n ->
    num_occur (Econstr x t ys e) v (n + (num_occur_list ys v))
| Num_occ_prim:
    forall x f ys e v n,
      num_occur e v n ->
      num_occur (Eprim x f ys e) v (n + (num_occur_list ys v))
| Num_occ_case:
    forall v' cl v n,
      num_occur_case cl v n -> 
      num_occur (Ecase v' cl) v (num_occur_list [v'] v + n)
| Num_occ_proj:
    forall e v n  y v' t n',
      num_occur  e v n ->
      num_occur (Eproj v' t n' y e) v (num_occur_list [y] v + n)
| Num_occ_app:
    forall f t ys v,
      num_occur (Eapp f t ys) v (num_occur_list (f::ys) v)
| Num_occ_fun:
    forall e v n m fl,
      num_occur e v n ->
      num_occur_fds fl v m ->
      num_occur (Efun fl e) v (n + m )
| Num_occ_halt:
    forall v v',
      num_occur (Ehalt v) v' (num_occur_list [v] v')
with num_occur_fds: fundefs -> var -> nat -> Prop :=
     | Num_occ_nil :
         forall v,
           num_occur_fds Fnil v 0
     | Num_occ_cons :
         forall v t n v' ys e fds' m,
           num_occur e v n ->
           num_occur_fds fds' v m ->
           num_occur_fds (Fcons v' t ys e fds') v (n + m)
with num_occur_case: list (var * exp) -> var -> nat -> Prop :=
     | Num_occ_cnil:
         forall v,
           num_occur_case [] v 0
     | Num_occur_ccons:
         forall v k cl e n m,
           num_occur e v n ->
           num_occur_case cl v m ->
           num_occur_case ((k,e)::cl) v (n+m).


(* number of times var occurs in a context *) 
Inductive num_occur_ec: exp_ctx -> var -> nat -> Prop :=
| Noec_hole: forall v, num_occur_ec Hole_c v 0
| Noec_constr:
  forall c v n x t ys,
    num_occur_ec c v n ->
    num_occur_ec (Econstr_c x t ys c) v (num_occur_list ys v + n)
| Noec_prim:
    forall c v n x f ys,
      num_occur_ec c v n ->
      num_occur_ec (Eprim_c x f ys c) v (num_occur_list ys v + n )
| Noec_proj:
    forall  v n y v' t n' c,
      num_occur_ec c v n ->
      num_occur_ec (Eproj_c v' t n' y c) v (num_occur_list [y] v + n)
| Noec_case:
    forall cl cl' c v n m tg y p,
      num_occur_case cl v n ->
      num_occur_ec c v m ->
      num_occur_case cl' v p ->
      num_occur_ec (Ecase_c y cl tg c cl') v (num_occur_list [y] v + n+m+p)
| Noec_fun1:
    forall n m fds c v,
      num_occur_ec c v n ->
      num_occur_fds fds v m ->
      num_occur_ec (Efun1_c fds c) v (n+m)
| Noec_fun2:
    forall n m fdc e v ,
      num_occur e v n ->
      num_occur_fdc fdc v m ->
               num_occur_ec (Efun2_c fdc e) v (n + m)
with num_occur_fdc : fundefs_ctx -> var -> nat -> Prop :=
     | Nofc_fcons1 :
         forall v n m fds t ys c f,
           num_occur_ec c v n ->
           num_occur_fds fds v m ->
           num_occur_fdc (Fcons1_c f t ys c fds) v  (n + m)
     | Nofc_fcons2 :
         forall e v n m fdc f t ys,
           num_occur e v n ->
           num_occur_fdc fdc v m ->
           num_occur_fdc (Fcons2_c f t ys e fdc) v (n + m).


Inductive num_binding_e: exp -> var -> nat -> Prop :=
| Ub_constr:
  forall v t ys e v' m,
    num_binding_e e v m -> 
    num_binding_e (Econstr v' t ys e) v (num_occur_list [v'] v + m)
| Ub_proj:
    forall v' t n' y e v n,
      num_binding_e e v n ->
      num_binding_e (Eproj v' t n' y e) v (num_occur_list [v'] v + n)
| Ub_prim:
    forall e v n x f ys,
      num_binding_e e v n ->
      num_binding_e (Eprim x f ys e) v (num_occur_list [x] v + n)
| Ub_app:
    forall f t ys v,
      num_binding_e (Eapp f t ys) v 0
| Ub_case:
    forall l v n y,
      num_binding_l l v n ->
      num_binding_e (Ecase y l ) v n
| Ub_fun:
    forall fds v n m e,
      num_binding_f fds v n ->
      num_binding_e e v m ->
      num_binding_e (Efun fds e) v (n+m)
| Ub_halt:
    forall v v',
      num_binding_e (Ehalt v) v' 0          
with num_binding_l: list (cTag*exp) -> var -> nat -> Prop :=
     | Ub_cons:
         forall e l v n m k,
           num_binding_e e v n ->
           num_binding_l l v m ->
           num_binding_l ((k,e)::l) v (n+m)
     | Ub_nil:
         forall v,
           num_binding_l [] v 0 
with num_binding_f : fundefs -> var -> nat -> Prop :=
     | Ub_fcons:
         forall e v n fds v' t ys m,
           num_binding_e e v n ->
           num_binding_f fds v m ->                        
           num_binding_f (Fcons v' t ys e fds) v (num_occur_list (v'::ys) v+n+m)
     | Ub_fnil:
         forall v,
           num_binding_f Fnil v 0.


Scheme nbe_ind := Induction for num_binding_e Sort Prop
                  with nbl_ind := Induction for num_binding_l Sort Prop
                  with nbf_ind:= Induction for num_binding_f Sort Prop.


Theorem e_num_binding :
  forall v e,
  exists n, num_binding_e e v n
with e_num_binding_f :
       forall v fds,
       exists n, num_binding_f fds v n.               
Proof.  
  - induction e; destructAll.
    + exists (num_occur_list [v0] v  + x); constructor; auto.
    + assert (exists n, num_binding_l l v n).
      { induction l.
        exists 0; constructor.
        destruct a.
        specialize (e_num_binding v e).
        destructAll. eexists; constructor; eauto.
      }
      destruct H. exists x; constructor; auto.
    + exists (num_occur_list [v0] v + x); constructor; auto.
    + specialize (e_num_binding_f v f).
      destructAll.
      eexists; constructor; eauto.
    + exists 0; constructor.
    + exists (num_occur_list [v0] v + x); constructor; auto.
    + exists 0; constructor.                 
  - induction fds.
    + specialize (e_num_binding v e). destructAll.
      eexists; constructor; eauto.
    + exists 0; constructor.
Qed.


    
Definition unique_bindings' e: Prop :=
  forall v,
  exists n,
    num_binding_e e v n /\ n <= 1.

Definition unique_binding_f' fds:Prop :=
  forall v, exists n,
    num_binding_f fds v n /\ n <= 1.


Theorem num_occur_n:
  forall e x n m,
    num_occur e x n ->
    n = m ->
    num_occur e x m.
Proof.
  intros; subst. apply H.
Qed.

Theorem num_occur_fds_n:
  forall f x n m,
    num_occur_fds f x n ->
    n = m ->
    num_occur_fds f x m.
Proof.
  intros; subst. apply H.
Qed.


Theorem num_occur_app_case:
  forall l' x l n,
    num_occur_case (l ++ l') x n <->
    exists n1 n2, num_occur_case l x n1 /\ num_occur_case l' x n2 /\ n1 + n2 = n.
Proof.
  induction l; split; intros.
  - exists 0, n.
    split.  constructor.
    split; auto.
  - destructAll.
    simpl. inv H.
    apply H0.
  - simpl in H.
    inv H. apply IHl in H5. destructAll.
    eexists. eexists.
    split. constructor; eauto.
    split; eauto.
    omega.
  - simpl.
    destructAll.
    inv H.
    replace (n + m + x1) with (n + (m + x1)) by omega.
    constructor. auto.
    apply IHl. exists m, x1. split; auto.     
Qed.


Local Hint Constructors num_occur num_occur_fds num_occur_case num_occur_ec num_occur_fdc.

Theorem num_occur_app_ctx_mut: 
  forall e x, 
    (forall c n, num_occur (c |[ e ]|) x n
            <-> exists n1 n2, num_occur_ec c x n1 /\ num_occur e x n2 /\ n = n1 + n2) /\
    (forall fc n,  num_occur_fds (fc <[ e ]>) x n
              <-> exists n1 n2, num_occur_fdc fc x n1 /\ num_occur e x n2 /\ n = n1 + n2).
Proof.
  intros e x.
  exp_fundefs_ctx_induction IHc IHf; split; intros.
  - simpl in H.
    exists 0, n. split; auto.
  - destructAll. simpl.
    inv H. apply H0.
  - inv H. apply IHc in H6. destructAll.
    eexists; eexists.
    split.
    constructor; eauto.
    split; eauto.
    omega.
  - destructAll.
    inv H.
    eapply num_occur_n.
    constructor. rewrite IHc.
    eexists; eexists; eauto.
    omega.
  - inv H. apply IHc in H7. destructAll.
    eexists; eexists.
    split.
    constructor; eauto.
    split; eauto.
    omega.
  - destructAll.
    inv H.
    eapply num_occur_n.
    constructor. rewrite IHc.
    eexists; eexists; eauto.
    omega.
  - inv H. apply IHc in H6. destructAll.
    eexists; eexists.
    split.
    constructor; eauto.
    split; eauto.
    omega.
  - destructAll.
    inv H.
    eapply num_occur_n.
    constructor. rewrite IHc.
    eexists; eexists; eauto.
    omega.
  - inv H.
    apply num_occur_app_case in H4.
    destructAll.
    inv H0. apply IHc in H6.
    destructAll.
    eexists; eexists.
    split.
    constructor; eauto.
    split. eauto.
    omega.
  - destructAll.
    inv H. simpl.
    eapply num_occur_n.
    constructor.
    apply num_occur_app_case. eexists; eexists. split; eauto.
    split. constructor; eauto. apply IHc. eexists; eexists; eauto.
    reflexivity.
    simpl. omega.
  - inv H. apply IHc in H2.
    destructAll.
    eexists; eexists.
    split.
    constructor; eauto.
    split; eauto.
    omega.
  - destructAll.
    inv H.
    eapply num_occur_n. simpl. constructor.
    apply IHc. eexists; eexists; eauto.
    apply H6.
    omega.
  - inv H.
    apply IHf in H5.
    destructAll.
    eexists; eexists.
    split.
    constructor; eauto.
    split; eauto.
    omega.
  - destructAll.
    inv H.
    simpl.
    eapply num_occur_n. constructor; eauto.
    apply IHf.
    eexists; eexists; eauto.
    omega.
  - inv H. apply IHc in H7.
    destructAll.
    eexists; eexists.
    split.
    constructor; eauto.
    split; eauto.
    omega.
  - destructAll.
    inv H.
    simpl.
    replace (n+ m + x1) with ((n + x1)+m) by omega.      
    constructor.
    apply IHc.
    eexists; eexists; eauto.
    eauto.
  - inv H.
    apply IHf in H8.
    destructAll.
    eexists; eexists.
    split.
    constructor; eauto.
    split; eauto.
    omega.
  - destructAll.
    inv H.
    simpl.
    replace (n+ m + x1) with (n + (m +x1)) by omega.      
    constructor.
    auto.
    apply IHf.
    eexists; eexists; eauto.    
Qed.

Theorem num_occur_app_ctx: 
  forall e x, 
    (forall c n, num_occur (c |[ e ]|) x n
            <-> exists n1 n2, num_occur_ec c x n1 /\ num_occur e x n2 /\ n = n1 + n2).
Proof.
  apply num_occur_app_ctx_mut.
Qed.

Theorem num_occur_fds_app_ctx: 
  forall e x, 
    (forall fc n,  num_occur_fds (fc <[ e ]>) x n
              <-> exists n1 n2, num_occur_fdc fc x n1 /\ num_occur e x n2 /\ n = n1 + n2).
Proof.
  apply num_occur_app_ctx_mut.
Qed.

Lemma e_num_occur_mut:
  forall v,
    (forall e, exists n, num_occur e v n) /\
    (forall fds, exists n, num_occur_fds fds v n).
Proof.
   intro v.
    apply exp_def_mutual_ind; intros; try (solve [destructAll; eexists; eauto]).
    - inv H; inv H0.
      inv H. eexists.
      constructor. constructor; eauto.
Qed.

Theorem e_num_occur:
  forall v,
    (forall e, exists n, num_occur e v n).                     
Proof.
  apply e_num_occur_mut.
Qed.  

Theorem e_num_occur_fds :
  forall v,
    (forall fds, exists n, num_occur_fds fds v n).                     
Proof.
  apply e_num_occur_mut.
Qed.  

Theorem num_occur_det:
  forall v, 
    (forall e n m,
       num_occur e v n ->
       num_occur e v m ->
       n = m) /\
    (forall fds n m,
       num_occur_fds fds v n ->
       num_occur_fds fds v m ->
       n = m).
Proof.
  intro.
  apply exp_def_mutual_ind; intros; try (inv H1; inv H0; eauto); try (inv H; inv H0; eauto).
  - inv H5. inv H4. reflexivity.
  - inv H1. inv H2. inv H7. inv H6.
    specialize (H0 (num_occur_list [v0] v + m) (num_occur_list [v0] v+m0)).
    replace (num_occur_list [v0] v + (n1 + m)) with (n1 + (num_occur_list [v0] v + m)) by omega.
    rewrite H0.
    specialize (H _ _ H8 H7). omega.
    constructor; auto.
    constructor; auto.                
  - inv H1; inv H2; eauto.
  - inv H1; inv H2; eauto.
Qed.


Theorem num_occur_ec_n:
  forall e x n m,
    num_occur_ec e x n ->
    n = m ->
    num_occur_ec e x m.
Proof.
  intros; subst; auto.
Qed.


Theorem num_occur_fdc_n:
  forall e x n m,
    num_occur_fdc e x n ->
    n = m ->
    num_occur_fdc e x m.
Proof.
  intros; subst; auto.
Qed.


Definition dead_var e: Ensemble var :=
  fun v => num_occur e v 0.

Definition dead_var_fundefs e: Ensemble var :=
  fun v => num_occur_fds e v 0.


Definition dead_var_ctx c:Ensemble var :=
  fun v => num_occur_ec c v 0.

Definition dead_var_fundefs_ctx f : Ensemble var :=
  fun v => num_occur_fdc f v 0.

Theorem num_occur_ec_comp_ctx_mut:
  (forall (c1 c2 : exp_ctx) (n : nat) x,
     num_occur_ec (comp_ctx_f c1 c2) x n <->
     (exists n1 n2 : nat,
        num_occur_ec c1 x n1 /\ num_occur_ec c2 x n2 /\ n = n1 + n2)) /\
  (forall (fc : fundefs_ctx) c (n : nat) x,
     num_occur_fdc (comp_f_ctx_f fc c) x n <->
     (exists n1 n2 : nat,
        num_occur_fdc fc x n1 /\ num_occur_ec c x n2 /\ n = n1 + n2)).
Proof.       
  exp_fundefs_ctx_induction IHc1 IHfc1; simpl; split; intros; eauto.
  - destructAll. inv H; auto.
  - inv H. apply IHc1 in H6. destructAll.
    eexists. exists x1. split.
    constructor; eauto. split; auto.
    omega.
  - destructAll.
    inv H.
    eapply num_occur_ec_n.
    constructor. rewrite IHc1. eauto.
    omega.
  - inv H. apply IHc1 in H7. destructAll.
    eexists. exists x1. split.
    constructor; eauto. split; auto.
    omega.
  - destructAll.
    inv H.
    eapply num_occur_ec_n.
    constructor. rewrite IHc1. eauto.
    omega.
  - inv H. apply IHc1 in H6. destructAll.
    eexists. exists x1. split.
    constructor; eauto. split; auto.
    omega.
  - destructAll.
    inv H.
    eapply num_occur_ec_n.
    constructor. rewrite IHc1. eauto.
    omega.
 - inv H. apply IHc1 in H8. destructAll.
    eexists. exists x1. split.
    constructor; eauto. split; auto.
    omega.
  - destructAll.
    inv H.
    eapply num_occur_ec_n.
    constructor; eauto. rewrite IHc1. eauto.
    omega.
 - inv H. apply IHc1 in H2. destructAll.
    eexists. exists x1. split.
    constructor; eauto. split; auto.
    omega.
  - destructAll.
    inv H.
    eapply num_occur_ec_n.
    constructor; eauto. rewrite IHc1. eauto.
    omega.
  - inv H. apply IHfc1 in H5. destructAll.
    eexists. exists x1. split.
    constructor; eauto. split; auto.
    omega.
  - destructAll.
    inv H.
    eapply num_occur_ec_n.
    constructor; eauto. rewrite IHfc1. eauto.
    omega.
      - inv H. apply IHc1 in H7. destructAll.
    eexists. exists x1. split.
    constructor; eauto. split; auto.
    omega.
  - destructAll.
    inv H.
    eapply num_occur_fdc_n.
    constructor; eauto. rewrite IHc1. eauto.
    omega.
  - inv H. apply IHfc1 in H8. destructAll.
    eexists. exists x1. split.
    constructor; eauto. split; auto.
    omega.
  - destructAll.
    inv H.
    eapply num_occur_fdc_n.
    constructor; eauto. rewrite IHfc1. eauto.
    omega.
Qed.
    
Theorem num_occur_ec_comp_ctx:
  (forall (c1 c2 : exp_ctx) (n : nat) x,
     num_occur_ec (comp_ctx_f c1 c2) x n <->
     (exists n1 n2 : nat,
        num_occur_ec c1 x n1 /\ num_occur_ec c2 x n2 /\ n = n1 + n2)).
Proof.
  intros. apply num_occur_ec_comp_ctx_mut.
Qed.   

Theorem num_occur_fdc_comp_ctx:
  (forall (fc : fundefs_ctx) c (n : nat) x,
     num_occur_fdc (comp_f_ctx_f fc c) x n <->
     (exists n1 n2 : nat,
        num_occur_fdc fc x n1 /\ num_occur_ec c x n2 /\ n = n1 + n2)).
Proof.
  intros. apply num_occur_ec_comp_ctx_mut.
Qed.   

Theorem num_occur_ec_det:
  forall c v n m,
    num_occur_ec c v n ->
    num_occur_ec c v m ->
    n = m.
Proof.
  intros.
  assert (num_occur (Ehalt v) v 1).
  eapply num_occur_n. constructor. simpl. destruct (var_dec v v). auto. exfalso; auto.
  assert (num_occur (c |[ Ehalt v ]|)  v (n +1)).
  apply num_occur_app_ctx. exists n, 1; auto.
  assert (num_occur (c |[ Ehalt v ]|)  v (m +1)).
  apply num_occur_app_ctx. exists m, 1; auto.
  eapply plus_reg_l.
  eapply (proj1 (num_occur_det _)). 
  rewrite Nat.add_comm.
  apply H2.
  rewrite Nat.add_comm.
  apply H3.
Qed.      
