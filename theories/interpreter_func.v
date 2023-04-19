(** Wasm interpreter **)
(* (C) J. Pichon, M. Bodin - see LICENSE.txt *)

From Wasm Require Import common opsem properties tactic type_preservation type_progress.
From Coq Require Import ZArith.BinInt.
From mathcomp Require Import ssreflect ssrfun ssrnat ssrbool eqtype seq.
From Wasm Require Export operations host type_checker.
Require Import BinNat.

Set Implicit Arguments.
Unset Strict Implicit.

Unset Printing Implicit Defensive.

Inductive res_crash : Type :=
| C_error : res_crash
| C_exhaustion : res_crash.

Scheme Equality for res_crash.
Definition res_crash_eqb c1 c2 := is_left (res_crash_eq_dec c1 c2).
Definition eqres_crashP : Equality.axiom res_crash_eqb :=
  eq_dec_Equality_axiom res_crash_eq_dec.

Canonical Structure res_crash_eqMixin := EqMixin eqres_crashP.
Canonical Structure res_crash_eqType := Eval hnf in EqType res_crash res_crash_eqMixin.

Inductive res : Type :=
| R_crash : res_crash -> res
| R_trap : res
| R_value : list value -> res.

Definition res_eq_dec : forall r1 r2 : res, {r1 = r2} + {r1 <> r2}.
Proof. decidable_equality. Defined.

Definition res_eqb (r1 r2 : res) : bool := res_eq_dec r1 r2.
Definition eqresP : Equality.axiom res_eqb :=
  eq_dec_Equality_axiom res_eq_dec.

Canonical Structure res_eqMixin := EqMixin eqresP.
Canonical Structure res_eqType := Eval hnf in EqType res res_eqMixin.

Section Host_func.

Variable host_function : eqType.
Let host := host host_function.

Variable host_instance : host.

Let store_record := store_record host_function.
(*Let administrative_instruction := administrative_instruction host_function.*)
Let host_state := host_state host_instance.

(*Let vs_to_es : seq value -> seq administrative_instruction := @vs_to_es _.*)

Let e_typing := @e_typing host_function.
Let inst_typing := @inst_typing host_function.

Variable host_application_impl : host_state -> store_record -> function_type -> host_function -> seq value ->
                       (host_state * option (store_record * result)).

Hypothesis host_application_impl_correct :
  (forall hs s ft hf vs hs' hres, (host_application_impl hs s ft hf vs = (hs', hres)) -> host_application hs s ft hf vs hs' hres).

Inductive res_step : Type :=
| RS_crash : res_crash -> res_step
| RS_break : nat -> list value -> res_step
| RS_return : list value -> res_step
| RS_normal : list administrative_instruction -> res_step.

(* TODO: the break/return cases also need some proofs to go with them,
 * see interpreter_func_sound. *)
Inductive res_step'
  (hs : host_state) (s : store_record) (f : frame)
  (es : list administrative_instruction) : Type :=
| RS'_exhaustion : res_step' hs s f es
| RS'_error : (~ exists C t, e_typing s C es t) -> res_step' hs s f es
| RS'_break : host_state -> store_record -> frame -> nat -> list value -> res_step' hs s f es (* TODO needs some reduce proof *)
| RS'_return : host_state -> store_record -> frame -> list value -> res_step' hs s f es (* TODO needs some reduce proof *)
| RS'_normal hs' s' f' es': reduce hs s f es hs' s' f' es' -> res_step' hs s f es.

Inductive res_step'_separate_e
  (hs : host_state) (s : store_record) (f : frame)
  (ves : list value) (e : administrative_instruction) : Type :=
| RS''_exhaustion : res_step'_separate_e hs s f ves e
| RS''_error :
    (~ exists C t1s t2s t1s',
      (* XXX easier to rev LHS or RHS? *)
      rev (map typeof ves) = t1s' ++ t1s /\
      inst_typing s f.(f_inst) C /\
      e_typing s C [::e] (Tf t1s t2s)) ->
    res_step'_separate_e hs s f ves e
(* | RS''_break *)
(* | RS''_return *)
| RS''_normal hs' s' f' es' :
    reduce hs s f ((vs_to_es ves) ++ [::e]) hs' s' f' es' ->
    res_step'_separate_e hs s f ves e.

(* Notation for RS'_normal. This forces hs', s', f' es' to be explicitly
 * stated. Their values could be inferred from the type of H instead but we
 * want to make those values clear. *)
Notation "<< hs' , s' , f' , es' >>[ H ]" := (@RS'_normal _ _ _ _ hs' s' f' es' H).
Notation "<< hs' , s' , f' , es' >>'" := (@RS''_normal _ _ _ _ _ hs' s' f' es').

(* Using this as a TODO placeholder *)
Axiom admitted_TODO : forall A : Type, A.

Definition res_step_eq_dec : forall r1 r2 : res_step, {r1 = r2} + {r1 <> r2}.
Proof. decidable_equality. Defined.

Definition res_step_eqb (r1 r2 : res_step) : bool := res_step_eq_dec r1 r2.
Definition eqres_stepP : Equality.axiom res_step_eqb :=
  eq_dec_Equality_axiom res_step_eq_dec.

Canonical Structure res_step_eqMixin := EqMixin eqres_stepP.
Canonical Structure res_step_eqType := Eval hnf in EqType res_step res_step_eqMixin.

Definition crash_error := RS_crash C_error.

Definition depth := nat.

Definition fuel := nat.

Definition config_tuple := ((host_state * store_record * frame * list administrative_instruction)%type).

Definition config_one_tuple_without_e := (host_state * store_record * frame * list value)%type.

Check config_typing.

Definition config_tuple_typing (cfg : config_tuple) (t : seq value_type) : Prop :=
  match cfg with
  | (_, s, f, es) => config_typing s f es t
  end.

Definition config_tuple_separate_e_typing (cfg : config_one_tuple_without_e) (e : administrative_instruction) (t : seq value_type) : Prop :=
  match cfg with
  | (_, s, f, vs) => config_typing s f ((vs_to_es vs) ++ [::e]) t
  end.

Definition res_tuple := (host_state * store_record * frame * res_step)%type.

(* TODO *)
Axiom coerce_res : forall hs s f es ves e (r : res_step'_separate_e hs s f ves e),
  res_step' hs s f es.

(* TODO auto instantiate lh, k? *)
(* TODO better name *)
Ltac solve_lfilled_0 :=
  unfold lfilled, lfill, vs_to_es;
  try rewrite v_to_e_is_const_list; apply/eqP; simplify_lists => //.

(* get f z = x from (H : rev (map f (z :: zs)) = xs ++ ys ++ [:: x]) *)
Ltac cats1_last_eq H :=
  rewrite rev_cons in H; rewrite <- cats1 in H; rewrite catA in H;
  apply concat_cancel_last in H as [??].

(* using (H : rev (map f [::]) = xs ++ ys), substitute xs = ys = [::] *)
Ltac apply_cat0_inv H :=
  match type of H with
  | _ = ?xs ++ ?ys => symmetry in H; apply cat0_inv in H as [??]; subst xs ys
  end.

(* TODO naming *)
Lemma vs_to_es_helper : forall v ves,
  vs_to_es ves ++ [:: AI_basic (BI_const v)] = vs_to_es (v :: ves).
Proof.
  intros.
  unfold vs_to_es. rewrite rev_cons. rewrite cats1. unfold v_to_e_list. rewrite map_rcons.
  by apply f_equal.
Qed.

Ltac simpl_reduce_simple :=
  (* TODO use some existing list ltacs instead of these initial matches? *)
  try match goal with
  | |- reduce _ _ _ (vs_to_es (?v :: ?ves') ++ [:: ?e]) _ _ _ _ =>
      replace (v :: ves') with ([:: v] ++ ves');
      last by apply cat1s
  | |- reduce
      _ _ _ (vs_to_es ?ves ++ [:: ?e])
      _ _ _ (vs_to_es ?ves ++ [:: ?e']) =>
      replace ves with ([::] ++ ves) at 1;
      last by apply cat0s
  end;
  try match goal with
  | |- reduce _ _ _ _ _ _ _ (vs_to_es (?v' :: ?ves')) =>
      replace (vs_to_es (v' :: ves'))
         with (vs_to_es ves' ++ [:: AI_basic (BI_const v')]);
      last by apply vs_to_es_helper
  end;
  match goal with
  | |- reduce
      _ _ _ (vs_to_es (?vs ++ ?ves') ++ [:: ?e])
      _ _ _ (vs_to_es ?ves' ++ [:: ?e']) =>
        eapply r_label with
          (k := 0) (lh := (LH_base (vs_to_es ves') [::]))
          (es := vs_to_es vs ++ [:: e])
          (es' := [:: e']);
        try solve_lfilled_0; apply r_simple
  end.

Lemma reduce_unreachable : forall (hs : host_state) s f ves,
  reduce
    hs s f (vs_to_es ves ++ [:: AI_basic BI_unreachable])
    hs s f (vs_to_es ves ++ [:: AI_trap]).
Proof. intros. simpl_reduce_simple. by apply rs_unreachable. Qed.

(* TODO extend simpl_reduce_simple to handle this? *)
Lemma reduce_nop : forall (hs : host_state) s f ves,
  reduce
    hs s f (vs_to_es ves ++ [:: AI_basic BI_nop])
    hs s f (vs_to_es ves).
Proof.
  intros.
  eapply r_label with
    (k := 0) (lh := (LH_base (vs_to_es ves) [::]))
    (es := [:: AI_basic BI_nop])
    (es' := [::]); try solve_lfilled_0.
  - apply r_simple. apply rs_nop.
  - solve_lfilled_0. by repeat rewrite List.app_nil_r.
Qed.

Lemma reduce_grow_memory : forall (hs : host_state) s s' f c v ves' mem'' s_mem_s_j j l,
  smem_ind s (f_inst f) = Some j ->
  List.nth_error (s_mems s) j = Some s_mem_s_j ->
  l = mem_size s_mem_s_j ->
  Some mem'' = mem_grow s_mem_s_j (Wasm_int.N_of_uint i32m c) ->
  s' = upd_s_mem s (update_list_at (s_mems s) j mem'') ->
  v = VAL_int32 (Wasm_int.int_of_Z i32m (Z.of_nat l)) ->
  reduce
    hs s f (vs_to_es (VAL_int32 c :: ves') ++ [:: AI_basic BI_grow_memory])
    hs s' f (vs_to_es (v :: ves')).
Proof.
  intros hs s s' f c v ves' mem'' s_mem_s_j j l ??????. subst s' v l.
  eapply r_label with (k := 0) (lh := (LH_base (vs_to_es ves') [::])).
  - apply r_grow_memory_success with (m := s_mem_s_j) (c := c) => //.
  - by solve_lfilled_0.
  - by solve_lfilled_0.
Qed.

(* XXX why is this needed for Grow_memory_typing and not for Binop_typing etc? *)
Let Grow_memory_typing := @Grow_memory_typing host_function.

Lemma grow_memory_error_0 : forall s inst ves,
  ves = [::] ->
  ~ exists C t1s t2s t1s',
    rev [seq typeof i | i <- ves] = t1s' ++ t1s /\
    inst_typing s inst C /\
    e_typing s C [:: AI_basic (BI_grow_memory)] (Tf t1s t2s).
Proof.
  intros s inst ves ? [C [t1s [t2s [t1s' [Ht1s [? Hetype]]]]]].
  subst ves.
  apply et_to_bet in Hetype as Hbtype; last by auto_basic.
  apply_cat0_inv Ht1s.
  by apply Grow_memory_typing in Hbtype as [[|] [? [??]]].
Qed.

Lemma grow_memory_error_TODO : forall s f ves ves' j s_mem_s_j l c,
  ves = VAL_int32 c :: ves' ->
  smem_ind s f.(f_inst) = Some j ->
  List.nth_error (s_mems s) j = Some s_mem_s_j ->
  l = mem_size s_mem_s_j ->
  None = mem_grow s_mem_s_j (Wasm_int.N_of_uint i32m c) ->
  ~ exists C t1s t2s t1s',
    rev [seq typeof i | i <- ves] = t1s' ++ t1s /\
    inst_typing s f.(f_inst) C /\
    e_typing s C [:: AI_basic (BI_grow_memory)] (Tf t1s t2s).
Proof.
  intros s f ves ves' j s_mem_s_j l c ?????
    [C [t1s [t2s [t1s' [Ht1s [? Hetype]]]]]].
  subst ves l.
    (* NOTE Heqmemgrow went wrong, get a contradiction with Hetype/Hitype? *)
  apply et_to_bet in Hetype as Hbtype; last by auto_basic.
  (* show t1s = t1s' = [::] *)
  apply Grow_memory_typing in Hbtype as [? [? [??]]] => //.
Admitted.

Lemma grow_memory_error_typeof : forall s inst v ves ves',
  typeof v <> T_i32 ->
  ves = v :: ves' ->
  ~ exists C t1s t2s t1s',
    rev [seq typeof i | i <- ves] = t1s' ++ t1s /\
    inst_typing s inst C /\
    e_typing s C [:: AI_basic (BI_grow_memory)] (Tf t1s t2s).
Proof.
  intros s inst v ves ves' Hv Heqves [C [t1s [t2s [t1s' [Ht1s [? Hetype]]]]]].
  subst ves.
  apply et_to_bet in Hetype as Hbtype; last by auto_basic.
  apply Grow_memory_typing in Hbtype as [? [? [??]]] => //. subst t1s t2s.
  by cats1_last_eq Ht1s.
Qed.

Lemma reduce_unop : forall (hs : host_state) s f t op v ves',
  reduce
    hs s f (vs_to_es (v :: ves') ++ [:: AI_basic (BI_unop t op)])
    hs s f (vs_to_es (app_unop op v :: ves')).
Proof. intros. simpl_reduce_simple. by apply rs_unop. Qed.

(* XXX could move C t1s t2s t1s' into the forall without changing semantics *)
Lemma unop_error : forall s inst ves t op,
  ves = [::] ->
  ~ exists C t1s t2s t1s',
    rev (map typeof ves) = t1s' ++ t1s /\
    inst_typing s inst C /\
    e_typing s C [:: AI_basic (BI_unop t op)] (Tf t1s t2s).
Proof.
  intros s inst ves t op Heqves [C [t1s [t2s [t1s' [Ht1s [? Hetype]]]]]].
  subst ves.
  apply et_to_bet in Hetype as Hbtype; last by auto_basic.
  apply_cat0_inv Ht1s.
  by apply Unop_typing in Hbtype as [? [[|] ?]].
  (* XXX which is better?
   * apply Unop_typing in Hbtype as [? [ts ?]]. by destruct ts => //. *)
Qed.

Lemma reduce_binop : forall (hs : host_state) s f t op v1 v2 v ves',
  app_binop op v1 v2 = Some v ->
  reduce
    hs s f (vs_to_es ([:: v2; v1] ++ ves') ++ [:: AI_basic (BI_binop t op)])
    hs s f (vs_to_es (v :: ves')).
Proof. intros. simpl_reduce_simple. by apply rs_binop_success. Qed.

(* XXX why is there a rule for this? shouldn't happen in a well typed
 * configuration *)
Lemma reduce_binop_trap : forall (hs : host_state) s f t op v1 v2 ves',
  app_binop op v1 v2 = None ->
  reduce
    hs s f (vs_to_es ([:: v2; v1] ++ ves') ++ [:: AI_basic (BI_binop t op)])
    hs s f (vs_to_es ves' ++ [:: AI_trap]).
Proof. intros. simpl_reduce_simple. by apply rs_binop_failure. Qed.

Lemma binop_error_0 : forall s inst ves t op,
  ves = [::] ->
  ~ exists C t1s t2s t1s',
    rev (map typeof ves) = t1s' ++ t1s /\
    inst_typing s inst C /\
    e_typing s C [:: AI_basic (BI_binop t op)] (Tf t1s t2s).
Proof.
  intros s inst ves t op Heqves [C [t1s [t2s [t1s' [Ht1s [? Hetype]]]]]].
  subst ves.
  apply et_to_bet in Hetype as Hbtype; last by auto_basic.
  apply_cat0_inv Ht1s.
  apply Binop_typing in Hbtype as [? [??]]. by destruct t2s => //.
Qed.

Lemma absurd_add_test : forall (n m : nat),
  1 <> n + 1 + 1.
Proof.
  intros n m.
  (* Nat.add_comm needs coq_nat scope *)
  Fail rewrite Nat.add_comm.
  lias.
Qed.

(* ves only has one value, binop needs at least two *)
Lemma binop_error_1 : forall s inst ves t op v,
  ves = [:: v] ->
  ~ exists C t1s t2s t1s',
    rev (map typeof ves) = t1s' ++ t1s /\
    inst_typing s inst C /\
    e_typing s C [:: AI_basic (BI_binop t op)] (Tf t1s t2s).
Proof.
  intros s inst ves t op v Heqves [C [t1s [t2s [t1s' [Ht1s [? Hetype]]]]]].
  subst ves.
  apply et_to_bet in Hetype as Hbtype; last by auto_basic.
  apply Binop_typing in Hbtype as [? [ts' ?]].
  subst t1s t2s.

  apply (f_equal size) in Ht1s. repeat rewrite size_cat in Ht1s.
  simpl in Ht1s. revert Ht1s. by lias.
Qed.

(* 0 arguments given to testop *)
Lemma testop_error_0 : forall s inst ves t testop,
  ves = [::] ->
  ~ exists C t1s t2s t1s',
    rev (map typeof ves) = t1s' ++ t1s /\
    inst_typing s inst C /\
    e_typing s C [:: AI_basic (BI_testop t testop)] (Tf t1s t2s).
Proof.
  intros s inst ves t testop ? [C [t1s [t2s [t1s' [Ht1s [? Hetype]]]]]].
  subst ves.
  apply et_to_bet in Hetype as Hbtype; last by auto_basic.
  apply_cat0_inv Ht1s.
  by apply Testop_typing in Hbtype as [[|] [??]].
Qed.

Lemma reduce_testop_i32 : forall (hs : host_state) s f ves' c testop,
  reduce
    hs s f (vs_to_es (VAL_int32 c :: ves') ++ [:: AI_basic (BI_testop T_i32 testop)])
    hs s f (vs_to_es (VAL_int32 (wasm_bool (app_testop_i testop c)) :: ves')).
Proof. intros. simpl_reduce_simple. by apply rs_testop_i32. Qed.

Lemma testop_i32_error : forall s inst v ves ves' testop,
  typeof v <> T_i32 ->
  ves = v :: ves' ->
  ~ exists C t1s t2s t1s',
    rev (map typeof ves) = t1s' ++ t1s /\
    inst_typing s inst C /\
    e_typing s C [:: AI_basic (BI_testop T_i32 testop)] (Tf t1s t2s).
Proof.
  intros s inst v ves ves' testop ?? [C [t1s [t2s [t1s' [Ht1s [? Hetype]]]]]].
  apply et_to_bet in Hetype as Hbtype; last by auto_basic.
  apply Testop_typing in Hbtype as [? [ts' ?]].
  subst ves t1s t2s.
  by cats1_last_eq Ht1s.
Qed.

Lemma reduce_testop_i64 : forall (hs : host_state) s f ves' c testop,
  reduce
    hs s f (vs_to_es (VAL_int64 c :: ves') ++ [:: AI_basic (BI_testop T_i64 testop)])
    hs s f (vs_to_es (VAL_int32 (wasm_bool (app_testop_i testop c)) :: ves')).
Proof. intros. simpl_reduce_simple. by apply rs_testop_i64. Qed.

Lemma testop_i64_error : forall s inst v ves ves' testop,
  typeof v <> T_i64 ->
  ves = v :: ves' ->
  ~ exists C t1s t2s t1s',
    rev (map typeof ves) = t1s' ++ t1s /\
    inst_typing s inst C /\
    e_typing s C [:: AI_basic (BI_testop T_i64 testop)] (Tf t1s t2s).
Proof.
  intros s inst v ves ves' testop ?? [C [t1s [t2s [t1s' [Ht1s [? Hetype]]]]]].
  apply et_to_bet in Hetype as Hbtype; last by auto_basic.
  apply Testop_typing in Hbtype as [? [ts' ?]].
  subst ves t1s t2s.
  by cats1_last_eq Ht1s.
Qed.

(* TODO dedupe these two (is_int_t = false)
 * or simpler to keep them separate? *)
Lemma testop_f32_error : forall s inst ves testop,
  ~ exists C t1s t2s t1s',
    rev (map typeof ves) = t1s' ++ t1s /\
    inst_typing s inst C /\
    e_typing s C [:: AI_basic (BI_testop T_f32 testop)] (Tf t1s t2s).
Proof.
  intros s inst ves testop [C [t1s [t2s [t1s' [Ht1s [? Hetype]]]]]].
  apply et_to_bet in Hetype as Hbtype; last by auto_basic.
  apply Testop_typing_is_int_t in Hbtype => //.
Qed.

Lemma testop_f64_error : forall s inst ves testop,
  ~ exists C t1s t2s t1s',
    rev (map typeof ves) = t1s' ++ t1s /\
    inst_typing s inst C /\
    e_typing s C [:: AI_basic (BI_testop T_f64 testop)] (Tf t1s t2s).
Proof.
  intros s inst ves testop [C [t1s [t2s [t1s' [Ht1s [? Hetype]]]]]].
  apply et_to_bet in Hetype as Hbtype; last by auto_basic.
  apply Testop_typing_is_int_t in Hbtype => //.
Qed.

(* XXX relop is very similar to binop, TODO dedupe *)
Lemma reduce_relop : forall (hs : host_state) s f t op v1 v2 ves',
  reduce
    hs s f (vs_to_es ([:: v2; v1] ++ ves') ++ [:: AI_basic (BI_relop t op)])
    hs s f (vs_to_es (VAL_int32 (wasm_bool (app_relop op v1 v2)) :: ves')).
Proof. intros. simpl_reduce_simple. by apply rs_relop. Qed.

Lemma relop_error_0 : forall s inst ves t op,
  ves = [::] ->
  ~ exists C t1s t2s t1s',
    rev (map typeof ves) = t1s' ++ t1s /\
    inst_typing s inst C /\
    e_typing s C [:: AI_basic (BI_relop t op)] (Tf t1s t2s).
Proof.
  intros s inst ves t op ? [C [t1s [t2s [t1s' [Ht1s [? Hetype]]]]]].
  subst ves.
  apply et_to_bet in Hetype as Hbtype; last by auto_basic.
  apply_cat0_inv Ht1s.
  by apply Relop_typing in Hbtype as [[|] [??]].
Qed.

(* ves only has one value, relop needs at least two *)
(* TODO dedupe with binop_error_1 *)
Lemma relop_error_1 : forall s inst ves t op v,
  ves = [:: v] ->
  ~ exists C t1s t2s t1s',
    rev (map typeof ves) = t1s' ++ t1s /\
    inst_typing s inst C /\
    e_typing s C [:: AI_basic (BI_relop t op)] (Tf t1s t2s).
Proof.
  intros s inst ves t op v Heqves [C [t1s [t2s [t1s' [Ht1s [? Hetype]]]]]].
  subst ves.
  apply et_to_bet in Hetype as Hbtype; last by auto_basic.
  apply Relop_typing in Hbtype as [? [ts' ?]].
  subst t1s t2s.

  apply (f_equal size) in Ht1s. repeat rewrite size_cat in Ht1s.
  simpl in Ht1s. revert Ht1s. by lias.
Qed.

(* TODO rename this and following lemmas from cvtop to convert *)
Lemma reduce_cvtop_success : forall (hs : host_state) s f t1 t2 sx v v' ves',
  types_agree t1 v ->
  cvt t2 sx v = Some v' ->
  reduce
    hs s f (vs_to_es (v :: ves') ++ [:: AI_basic (BI_cvtop t2 CVO_convert t1 sx)])
    hs s f (vs_to_es (v' :: ves')).
Proof.
  intros hs s f t1 t2 sx v v' ves' ??.
  simpl_reduce_simple.
  by apply rs_convert_success with (t1 := t1) (t2 := t2) (v := v) (v' := v') (sx := sx).
Qed.

Lemma reduce_cvtop_trap : forall (hs : host_state) s f t1 t2 sx v ves',
  types_agree t1 v ->
  cvt t2 sx v = None ->
  reduce
    hs s f (vs_to_es (v :: ves') ++ [:: AI_basic (BI_cvtop t2 CVO_convert t1 sx)])
    hs s f (vs_to_es ves' ++ [::AI_trap]).
Proof.
  intros hs s f t1 t2 sx v ves' ??.
  simpl_reduce_simple.
  by apply rs_convert_failure with (t1 := t1) (t2 := t2) (v := v) (sx := sx).
Qed.

Lemma cvtop_error_0 : forall s inst ves t1 t2 cvtop sx,
  ves = [::] ->
  ~ exists C t1s t2s t1s',
    rev (map typeof ves) = t1s' ++ t1s /\
    inst_typing s inst C /\
    e_typing s C [:: AI_basic (BI_cvtop t2 cvtop t1 sx)] (Tf t1s t2s).
Proof.
  intros s inst ves t1 t2 cvtop sx ? [C [t1s [t2s [t1s' [Ht1s [? Hetype]]]]]].
  subst ves.
  apply et_to_bet in Hetype as Hbtype; last by auto_basic.
  apply_cat0_inv Ht1s.
  by apply Cvtop_typing in Hbtype as [[|] [??]].
Qed.

Lemma cvtop_error_types_disagree : forall s inst v ves ves' t1 t2 sx,
  ves = v :: ves' ->
  ~ types_agree t1 v ->
  ~ exists C t1s t2s t1s',
    rev (map typeof ves) = t1s' ++ t1s /\
    inst_typing s inst C /\
    e_typing s C [:: AI_basic (BI_cvtop t2 CVO_convert t1 sx)] (Tf t1s t2s).
Proof.
  intros s inst v ves ves' t1 t2 sx ? Hdisagree [C [t1s [t2s [t1s' [Ht1s [? Hetype]]]]]].
  subst ves.
  apply et_to_bet in Hetype as Hbtype; last by auto_basic.
  apply Cvtop_convert_typing in Hbtype.
  unfold convert_helper in Hbtype.
  (* TODO contradict Hbtype with Hdisagree *)
Admitted.

Lemma reduce_reinterpret : forall (hs : host_state) s f t1 t2 v ves',
  types_agree t1 v ->
  reduce
    hs s f (vs_to_es (v :: ves') ++ [:: AI_basic (BI_cvtop t2 CVO_reinterpret t1 None)])
    hs s f (vs_to_es (wasm_deserialise (bits v) t2 :: ves')).
Proof.
  intros hs s f t1 t2 v ves' ?.
  simpl_reduce_simple.
  by apply rs_reinterpret with (t1 := t1) (v := v).
Qed.


(* TODO many of the eqn:* can be removed by using partial application of RS_* *)
Theorem run_step_with_fuel'' hs s f es (fuel : fuel) (d : depth) : res_step' hs s f es
with run_one_step'' hs s f ves e (fuel : fuel) (d : depth) : res_step'_separate_e hs s f ves e.
(* TODO should use res_step'_separate_e *)
Proof.
  (* NOTE: not indenting the two main subgoals - XXX use {}? *)
  (* run_step_with_fuel'' *)
  destruct fuel as [|fuel].
  - (* 0 *)
    by apply (RS'_exhaustion hs s f es).
  - (* fuel.+1 *)
    (** Framing out constants. **)
    destruct (split_vals_e es) as [ves es'] eqn:Heqes.
    destruct es' as [|e es''] eqn:Heqes'.
    * (* es' = [::] *)
      by apply (RS'_error _ _ (admitted_TODO (~ exists C t, e_typing s C es t))).
    * (* es' = e :: es'' *)
      destruct (e_is_trap e).
      + destruct ((es'' != [::]) || (ves != [::])).
        -- by apply <<hs, s, f, [::AI_trap]>>[admitted_TODO _].
        -- by apply (RS'_error _ _ (admitted_TODO (~ exists C t, e_typing s C es t))).
      + remember (run_one_step'' hs s f (rev ves) e fuel d) as r.
        by apply (if r is RS''_normal hs' s' f' es' _
          then <<hs', s', f', (es' ++ es'')>>[admitted_TODO _]
          else coerce_res _ r).

  (* run_one_step'' *)
  (* initial es, useful as an arg for reduce *)
  remember ((vs_to_es ves) ++ [::e]) as es0 eqn:Heqes0.
  destruct fuel as [|fuel].
  - (* 0 *)
    by apply RS''_exhaustion.
  - (* fuel.+1 *)
    destruct e as [
      (* AI_basic *) [
      (* BI_unreachable *) |
      (* BI_nop *) |
      (* BI_drop *) |
      (* BI_select *) |
      (* BI_block (Tf t1s t2s) es *) [t1s t2s] es |
      (* BI_loop (Tf t1s t2s) es *) [t1s t2s] es |
      (* BI_if tf es1 es2 *) tf es1 es2 |
      (* BI_br j *) j |
      (* BI_br_if j *) j |
      (* BI_br_table js j *) js j |
      (* BI_return *) |
      (* BI_call j *) j |
      (* BI_call_indirect j *) j |
      (* BI_get_local j *) j |
      (* BI_set_local j *) j |
      (* BI_tee_local j *) j |
      (* BI_get_global j *) j |
      (* BI_set_global j *) j |
      (* BI_load t [Some (tp, sx)|None] a off *) t [[tp sx]|] a off |
      (* BI_store t [Some tp|None] a off *) t [tp|] a off |
      (* BI_current_memory *) |
      (* BI_grow_memory *) |
      (* BI_const _ *) |
      (* BI_unop t op *) t op |
      (* BI_binop t op *) t op |
      (* BI_testop [T_i32|T_i64|T_f32|T_f64] testop *) [| | |] testop |
      (* BI_relop t op *) t op |
      (* BI_cvtop t2 [CVO_convert|CVO_reinterpret] t1 sx *) t2 [|] t1 sx ] |
      (* AI_trap *) |
      (* AI_invoke a *) a |
      (* AI_label ln les es *) ln les es |
      (* AI_local ln lf es *) ln lf es ].

    * (* AI_basic BI_unreachable *)
      apply <<hs, s, f, vs_to_es ves ++ [:: AI_trap]>>'.
      by apply reduce_unreachable.

    * (* AI_basic BI_nop *)
      apply <<hs, s, f, vs_to_es ves>>'.
      by apply reduce_nop.

    * (* AI_basic BI_drop *)
      destruct ves as [|v ves'] eqn:Heqves.
      + (* [::] *)
        apply RS''_error.
        by apply (admitted_TODO _).
      + (* v :: ves' *)
        apply <<hs, s, f, vs_to_es ves'>>'.
        by apply (admitted_TODO _).

    * (* AI_basic BI_select *)
      by apply (admitted_TODO _).
    * (* AI_basic (BI_block (Tf t1s t2s) es) *)
      by apply (admitted_TODO _).
    * (* AI_basic (BI_loop (Tf t1s t2s) es) *)
      by apply (admitted_TODO _).
    * (* AI_basic (BI_if tf es1 t2) *)
      by apply (admitted_TODO _).
    * (* AI_basic (BI_br j) *)
      by apply (admitted_TODO _).
    * (* AI_basic (BI_br_if j) *)
      by apply (admitted_TODO _).
    * (* AI_basic (BI_br_table js j) *)
      by apply (admitted_TODO _).
    * (* AI_basic BI_return *)
      by apply (admitted_TODO _).
    * (* AI_basic (BI_call j) *)
      by apply (admitted_TODO _).
    * (* AI_basic (BI_call_indirect j) *)
      by apply (admitted_TODO _).
    * (* AI_basic (BI_get_local j) *)
      by apply (admitted_TODO _).
    * (* AI_basic (BI_set_local j) *)
      by apply (admitted_TODO _).
    * (* AI_basic (BI_tee_local j) *)
      by apply (admitted_TODO _).
    * (* AI_basic (BI_get_global j) *)
      by apply (admitted_TODO _).
    * (* AI_basic (BI_set_global j) *)
      by apply (admitted_TODO _).
    * (* AI_basic (BI_load t (Some (tp, sx)) a off) *)
      by apply (admitted_TODO _).
    * (* AI_basic (BI_load t None a off) *)
      by apply (admitted_TODO _).
    * (* AI_basic (BI_store t (Some tp) a off) *)
      by apply (admitted_TODO _).
    * (* AI_basic (BI_store t None a off) *)
      by apply (admitted_TODO _).
    * (* AI_basic BI_current_memory *)
      by apply (admitted_TODO _).

    * (* AI_basic BI_grow_memory *)
      (* XXX this branch is fairly complicated,
       * would moving it out into a separate function be justified?
       * perhaps use a convoy pattern match there?  *)
      (* XXX do we ever have to handle r_grow_memory_failure? *)
      destruct ves as [|[c| | |] ves'] eqn:Heqves;
        try by (apply RS''_error; by eapply grow_memory_error_typeof => //).
      + (* [::] *)
        apply RS''_error. by apply grow_memory_error_0.
      + (* VAL_int32 c :: ves' *)
        destruct (smem_ind s f.(f_inst)) as [j|] eqn:Heqj.
        -- (* Some j *)
           destruct (List.nth_error s.(s_mems) j) as [s_mem_s_j|] eqn:Heqsmem.
           ** (* Some s_mem_s_j *)
              remember (mem_grow s_mem_s_j (Wasm_int.N_of_uint i32m c)) as mem' eqn:Heqmem'.
              destruct mem' as [mem''|] eqn:Heqmem.
              ++ (* Some mem'' *)
                 remember (VAL_int32 (Wasm_int.int_of_Z i32m (Z.of_nat (mem_size s_mem_s_j)))) as v.
                 remember (upd_s_mem s (update_list_at s.(s_mems) j mem'')) as s'.
                 (* TODO maybe a better approach would be to use eapply and let
                  * coq find Heq* automatically? *)
                 apply <<hs, s', f, (vs_to_es (v :: ves'))>>'.
                 eapply reduce_grow_memory with (j := j) (s_mem_s_j := s_mem_s_j) (mem'' := mem'') => //.
              ++ (* None *)
                 apply RS''_error.
                 by eapply grow_memory_error_TODO with (j := j) (s_mem_s_j := s_mem_s_j) => //.
           ** (* None *)
              by apply (RS''_error _ (admitted_TODO _)).

        -- (* None *)
           by apply (RS''_error _ (admitted_TODO _)).

    * (* AI_basic (BI_const _) *)
      (* XXX this won't happen if ves has been correctly split(?) *)
      by apply (admitted_TODO _).

    * (* AI_basic (BI_unop t op) *)
      destruct ves as [|v ves'].
      + (* [::] *)
        apply RS''_error. by apply unop_error.
      + (* v :: ves' *)
        apply <<hs, s, f, vs_to_es (app_unop op v :: ves')>>'.
        by apply reduce_unop.

    * (* AI_basic (BI_binop t op) *)
      destruct ves as [|v2 [|v1 ves']].
      + (* [::] *)
        apply RS''_error. by apply binop_error_0.
      + (* [:: v2] *)
        apply RS''_error. by eapply binop_error_1.
      + (* [:: v2, v1 & ves'] *)
        destruct (app_binop op v1 v2) as [v|] eqn:?.
        -- (* Some v *)
           apply <<hs, s, f, vs_to_es (v :: ves')>>'.
           by apply reduce_binop.
        -- (* None *)
           apply <<hs, s, f, (vs_to_es ves') ++ [:: AI_trap]>>'.
           by apply reduce_binop_trap.

    * (* AI_basic (BI_testop T_i32 testop) *)
      destruct ves as [|[c| | |] ves'] eqn:?;
        try by (apply RS''_error; by eapply testop_i32_error => //).
      + (* [::] *)
        apply RS''_error. by apply testop_error_0.
      + (* VAL_int32 c :: ves' *)
        apply <<hs, s, f, vs_to_es (VAL_int32 (wasm_bool (@app_testop_i i32t testop c)) :: ves')>>'.
        by apply reduce_testop_i32.

    * (* AI_basic (BI_testop T_i64 testop) *)
      (* TODO un-nest this destruct? could make the 'try by' clearer *)
      destruct ves as [|[|c| |] ves'] eqn:?;
          try by (apply RS''_error; by eapply testop_i64_error => //).
      + (* [::] *)
        apply RS''_error. by apply testop_error_0.
      + (* VAL_int64 c :: ves' *)
        apply <<hs, s, f, vs_to_es (VAL_int32 (wasm_bool (@app_testop_i i64t testop c)) :: ves')>>'.
        by eapply reduce_testop_i64.

    * (* AI_basic (BI_testop T_f32 testop) *)
      apply RS''_error. by apply testop_f32_error.

    * (* AI_basic (BI_testop T_f64 testop) *)
      apply RS''_error. by apply testop_f64_error.

    * (* AI_basic (BI_relop t op) *)
      destruct ves as [|v2 [|v1 ves']] eqn:?.
      + (* [::] *)
        apply RS''_error. by apply relop_error_0.
      + (* [:: v2] *)
        apply RS''_error. by eapply relop_error_1.
      + (* [:: v2, v1 & ves'] *)
        apply <<hs, s, f, vs_to_es (VAL_int32 (wasm_bool (app_relop op v1 v2)) :: ves')>>'.
        by apply reduce_relop.

    * (* AI_basic (BI_cvtop t2 CVO_convert t1 sx) *)
      destruct ves as [|v ves'] eqn:?.
      + (* [::] *)
        apply RS''_error. by apply cvtop_error_0.
      + destruct (types_agree t1 v) eqn:Ht1.
        -- (* true *)
           destruct (cvt t2 sx v) as [v'|] eqn:Heqv'.
           ** (* Some v' *)
              apply <<hs, s, f, vs_to_es (v' :: ves')>>'.
              by apply reduce_cvtop_success.
           ** (* None *)
              apply <<hs, s, f, vs_to_es ves' ++ [::AI_trap]>>'.
              by apply reduce_cvtop_trap.
        -- (* false *)
           apply RS''_error.
           assert (~ types_agree t1 v). { rewrite Ht1. by apply not_false_is_true. }
           eapply cvtop_error_types_disagree => //.  (* TODO lemma not finished *)

    * (* AI_basic (BI_cvtop t2 CVO_reinterpret t1 sx) *)
      destruct ves as [|v ves'] eqn:?.
      + (* [::] *)
        apply RS''_error. by apply cvtop_error_0.
      + destruct (types_agree t1 v) eqn:Ht1.
        -- (* true *)
           destruct sx eqn:Heqsx.
           ** (* Some _ *)
              apply RS''_error. by apply (admitted_TODO _).
           ** (* None *)
              apply <<hs, s, f, (vs_to_es (wasm_deserialise (bits v) t2 :: ves'))>>'.
              by apply reduce_reinterpret.
        -- (* false *)
           apply RS''_error. by apply (admitted_TODO _).

    * (* AI_trap *)
      (* NOTE trap is 'terminal/value form' *)
      by apply (admitted_TODO _).

    * (* AI_invoke a *)
      by apply (admitted_TODO _).
    * (* AI_label ln les es *)
      by apply (admitted_TODO _).
    * (* AI_local ln lf es *)
      by apply (admitted_TODO _).
Defined.

(***************************************)

Fixpoint run_step_with_fuel (fuel : fuel) (d : depth) (cfg : config_tuple) : res_tuple :=
  let: (hs, s, f, es) := cfg in
  match fuel with
  | 0 => (hs, s, f, RS_crash C_exhaustion)
  | fuel.+1 =>
    let: (ves, es') := split_vals_e es in (** Framing out constants. **)
    match es' with
    | [::] => (hs, s, f, crash_error)
    | e :: es'' =>
      if e_is_trap e
      then
        if (es'' != [::]) || (ves != [::])
        then (hs, s, f, RS_normal [::AI_trap])
        else (hs, s, f, crash_error)
      else
        let: (hs', s', f', r) := run_one_step fuel d (hs, s, f, (rev ves)) e in
        if r is RS_normal res
        then (hs', s', f', RS_normal (res ++ es''))
        else (hs', s', f', r)
    end
  end

with run_one_step (fuel : fuel) (d : depth) (cfg : config_one_tuple_without_e) (e : administrative_instruction) : res_tuple :=
  let: (hs, s, f, ves) := cfg in
  match fuel with
  | 0 => (hs, s, f, RS_crash C_exhaustion)
  | fuel.+1 =>
    match e with
    (* unop *)
    | AI_basic (BI_unop t op) =>
      if ves is v :: ves' then
        (hs, s, f, RS_normal (vs_to_es (app_unop op v :: ves')))
      else (hs, s, f, crash_error)
    (* binop *)
    | AI_basic (BI_binop t op) =>
      if ves is v2 :: v1 :: ves' then
        expect (app_binop op v1 v2)
               (fun v => (hs, s, f, RS_normal (vs_to_es (v :: ves'))))
               (hs, s, f, RS_normal ((vs_to_es ves') ++ [::AI_trap]))
      else (hs, s, f, crash_error)
    (* testops *)
    | AI_basic (BI_testop T_i32 testop) =>
      if ves is (VAL_int32 c) :: ves' then
        (hs, s, f, RS_normal (vs_to_es ((VAL_int32 (wasm_bool (@app_testop_i i32t testop c))) :: ves')))
      else (hs, s, f, crash_error)
    | AI_basic (BI_testop T_i64 testop) =>
      if ves is (VAL_int64 c) :: ves' then
        (hs, s, f, RS_normal (vs_to_es ((VAL_int32 (wasm_bool (@app_testop_i i64t testop c))) :: ves')))
      else (hs, s, f, crash_error)
    | AI_basic (BI_testop _ _) => (hs, s, f, crash_error)
    (* relops *)
    | AI_basic (BI_relop t op) =>
      if ves is v2 :: v1 :: ves' then
        (hs, s, f, RS_normal (vs_to_es (VAL_int32 (wasm_bool (app_relop op v1 v2)) :: ves')))
      else (hs, s, f, crash_error)
    (* convert & reinterpret *)
    | AI_basic (BI_cvtop t2 CVO_convert t1 sx) =>
      if ves is v :: ves' then
        if types_agree t1 v
        then
          expect (cvt t2 sx v) (fun v' =>
               (hs, s, f, RS_normal (vs_to_es (v' :: ves'))))
            (hs, s, f, RS_normal ((vs_to_es ves') ++ [::AI_trap]))
        else (hs, s, f, crash_error)
      else (hs, s, f, crash_error)
    | AI_basic (BI_cvtop t2 CVO_reinterpret t1 sx) =>
      if ves is v :: ves' then
        if types_agree t1 v && (sx == None)
        then (hs, s, f, RS_normal (vs_to_es (wasm_deserialise (bits v) t2 :: ves')))
        else (hs, s, f, crash_error)
      else (hs, s, f, crash_error)
    (**)
    | AI_basic BI_unreachable => (hs, s, f, RS_normal ((vs_to_es ves) ++ [::AI_trap]))
    | AI_basic BI_nop => (hs, s, f, RS_normal (vs_to_es ves))
    | AI_basic BI_drop =>
      if ves is v :: ves' then
        (hs, s, f, RS_normal (vs_to_es ves'))
      else (hs, s, f, crash_error)
    | AI_basic BI_select =>
      if ves is (VAL_int32 c) :: v2 :: v1 :: ves' then
        if c == Wasm_int.int_zero i32m
        then (hs, s, f, RS_normal (vs_to_es (v2 :: ves')))
        else (hs, s, f, RS_normal (vs_to_es (v1 :: ves')))
      else (hs, s, f, crash_error)
    | AI_basic (BI_block (Tf t1s t2s) es) =>
      if length ves >= length t1s
      then
        let: (ves', ves'')  := split_n ves (length t1s) in
        (hs, s, f, RS_normal (vs_to_es ves''
                ++ [::AI_label (length t2s) [::] (vs_to_es ves' ++ to_e_list es)]))
      else (hs, s, f, crash_error)
    | AI_basic (BI_loop (Tf t1s t2s) es) =>
      if length ves >= length t1s
      then
        let: (ves', ves'') := split_n ves (length t1s) in
        (hs, s, f, RS_normal (vs_to_es ves''
                ++ [::AI_label (length t1s) [::AI_basic (BI_loop (Tf t1s t2s) es)]
                        (vs_to_es ves' ++ to_e_list es)]))
      else (hs, s, f, crash_error)
    | AI_basic (BI_if tf es1 es2) =>
      if ves is VAL_int32 c :: ves' then
        if c == Wasm_int.int_zero i32m
        then (hs, s, f, RS_normal (vs_to_es ves' ++ [::AI_basic (BI_block tf es2)]))
        else (hs, s, f, RS_normal (vs_to_es ves' ++ [::AI_basic (BI_block tf es1)]))
      else (hs, s, f, crash_error)
    | AI_basic (BI_br j) => (hs, s, f, RS_break j ves)
    | AI_basic (BI_br_if j) =>
      if ves is VAL_int32 c :: ves' then
        if c == Wasm_int.int_zero i32m
        then (hs, s, f, RS_normal (vs_to_es ves'))
        else (hs, s, f, RS_normal (vs_to_es ves' ++ [::AI_basic (BI_br j)]))
      else (hs, s, f, crash_error)
    | AI_basic (BI_br_table js j) =>
      if ves is VAL_int32 c :: ves' then
        let: k := Wasm_int.nat_of_uint i32m c in
        if k < length js
        then
          expect (List.nth_error js k) (fun js_at_k =>
              (hs, s, f, RS_normal (vs_to_es ves' ++ [::AI_basic (BI_br js_at_k)])))
            (hs, s, f, crash_error)
        else (hs, s, f, RS_normal (vs_to_es ves' ++ [::AI_basic (BI_br j)]))
      else (hs, s, f, crash_error)
    | AI_basic (BI_call j) =>
      if List.nth_error f.(f_inst).(inst_funcs) j is Some a then
        (hs, s, f, RS_normal (vs_to_es ves ++ [::AI_invoke a]))
      else (hs, s, f, crash_error)
    | AI_basic (BI_call_indirect j) =>
      if ves is VAL_int32 c :: ves' then
        match stab_addr s f (Wasm_int.nat_of_uint i32m c) with
        | Some a =>
          match List.nth_error s.(s_funcs) a with
          | Some cl =>
            if stypes s f.(f_inst) j == Some (cl_type cl)
            then (hs, s, f, RS_normal (vs_to_es ves' ++ [::AI_invoke a]))
            else (hs, s, f, RS_normal (vs_to_es ves' ++ [::AI_trap]))        
          | None => (hs, s, f, crash_error)
          end
        | None => (hs, s, f, RS_normal (vs_to_es ves' ++ [::AI_trap]))
        end
      else (hs, s, f, crash_error)
    | AI_basic BI_return => (hs, s, f, RS_return ves)
    | AI_basic (BI_get_local j) =>
      if j < length f.(f_locs)
      then
        expect (List.nth_error f.(f_locs) j) (fun vs_at_j =>
            (hs, s, f, RS_normal (vs_to_es (vs_at_j :: ves))))
          (hs, s, f, crash_error)
      else (hs, s, f, crash_error)
    | AI_basic (BI_set_local j) =>
      if ves is v :: ves' then
        if j < length f.(f_locs)
        then (hs, s, Build_frame (update_list_at f.(f_locs) j v) f.(f_inst), RS_normal (vs_to_es ves'))
        else (hs, s, f, crash_error)
      else (hs, s, f, crash_error)
    | AI_basic (BI_tee_local j) =>
      if ves is v :: ves' then
        (hs, s, f, RS_normal (vs_to_es (v :: ves) ++ [::AI_basic (BI_set_local j)]))
      else (hs, s, f, crash_error)
    | AI_basic (BI_get_global j) =>
      if sglob_val s f.(f_inst) j is Some xx
      then (hs, s, f, RS_normal (vs_to_es (xx :: ves)))
      else (hs, s, f, crash_error)
    | AI_basic (BI_set_global j) =>
      if ves is v :: ves' then
        if supdate_glob s f.(f_inst) j v is Some xx
        then (hs, xx, f, RS_normal (vs_to_es ves'))
        else (hs, s, f, crash_error)
      else (hs, s, f, crash_error)
    | AI_basic (BI_load t None a off) =>
      if ves is VAL_int32 k :: ves' then
        expect
          (smem_ind s f.(f_inst))
          (fun j =>
             if List.nth_error s.(s_mems) j is Some mem_s_j then
               expect
                 (load (mem_s_j) (Wasm_int.N_of_uint i32m k) off (t_length t))
                 (fun bs => (hs, s, f, RS_normal (vs_to_es (wasm_deserialise bs t :: ves'))))
                 (hs, s, f, RS_normal (vs_to_es ves' ++ [::AI_trap]))
             else (hs, s, f, crash_error))
          (hs, s, f, crash_error)
      else (hs, s, f, crash_error)
    | AI_basic (BI_load t (Some (tp, sx)) a off) =>
      if ves is VAL_int32 k :: ves' then
        expect
          (smem_ind s f.(f_inst))
          (fun j =>
             if List.nth_error s.(s_mems) j is Some mem_s_j then
               expect
                 (load_packed sx (mem_s_j) (Wasm_int.N_of_uint i32m k) off (tp_length tp) (t_length t))
                 (fun bs => (hs, s, f, RS_normal (vs_to_es (wasm_deserialise bs t :: ves'))))
                 (hs, s, f, RS_normal (vs_to_es ves' ++ [::AI_trap]))
             else (hs, s, f, crash_error))
          (hs, s, f, crash_error)
      else (hs, s, f, crash_error)
    | AI_basic (BI_store t None a off) =>
      if ves is v :: VAL_int32 k :: ves' then
        if types_agree t v
        then
          expect
            (smem_ind s f.(f_inst))
            (fun j =>
               if List.nth_error s.(s_mems) j is Some mem_s_j then
                 expect
                   (store mem_s_j (Wasm_int.N_of_uint i32m k) off (bits v) (t_length t))
                   (fun mem' =>
                      (hs, upd_s_mem s (update_list_at s.(s_mems) j mem'), f, RS_normal (vs_to_es ves')))
                   (hs, s, f, RS_normal (vs_to_es ves' ++ [::AI_trap]))
               else (hs, s, f, crash_error))
            (hs, s, f, crash_error)
        else (hs, s, f, crash_error)
      else (hs, s, f, crash_error)
    | AI_basic (BI_store t (Some tp) a off) =>
      if ves is v :: VAL_int32 k :: ves' then
        if types_agree t v
        then
          expect
            (smem_ind s f.(f_inst))
            (fun j =>
               if List.nth_error s.(s_mems) j is Some mem_s_j then
                 expect
                   (store_packed mem_s_j (Wasm_int.N_of_uint i32m k) off (bits v) (tp_length tp))
                   (fun mem' =>
                      (hs, upd_s_mem s (update_list_at s.(s_mems) j mem'), f, RS_normal (vs_to_es ves')))
                   (hs, s, f, RS_normal (vs_to_es ves' ++ [::AI_trap]))
               else (hs, s, f, crash_error))
            (hs, s, f, crash_error)
        else (hs, s, f, crash_error)
      else (hs, s, f, crash_error)
    | AI_basic BI_current_memory =>
      expect
        (smem_ind s f.(f_inst))
        (fun j =>
           if List.nth_error s.(s_mems) j is Some s_mem_s_j then
             (hs, s, f, RS_normal (vs_to_es (VAL_int32 (Wasm_int.int_of_Z i32m (Z.of_nat (mem_size s_mem_s_j))) :: ves)))
           else (hs, s, f, crash_error))
        (hs, s, f, crash_error)
    | AI_basic BI_grow_memory =>
      if ves is VAL_int32 c :: ves' then
        expect
          (smem_ind s f.(f_inst))
          (fun j =>
            if List.nth_error s.(s_mems) j is Some s_mem_s_j then
              let: l := mem_size s_mem_s_j in
              let: mem' := mem_grow s_mem_s_j (Wasm_int.N_of_uint i32m c) in
              if mem' is Some mem'' then
                (hs, upd_s_mem s (update_list_at s.(s_mems) j mem''), f,
                 RS_normal (vs_to_es (VAL_int32 (Wasm_int.int_of_Z i32m (Z.of_nat l)) :: ves')))
              else (hs, s, f, crash_error)
            else (hs, s, f, crash_error))
          (hs, s, f, crash_error)
      else (hs, s, f, crash_error)
    | AI_basic (BI_const _) => (hs, s, f, crash_error)
    | AI_invoke a =>
      match List.nth_error s.(s_funcs) a with
      | Some cl => 
        match cl with
        | FC_func_native i (Tf t1s t2s) ts es =>
            let: n := length t1s in
            let: m := length t2s in
            if length ves >= n
            then
            let: (ves', ves'') := split_n ves n in
            let: zs := n_zeros ts in
            (hs, s, f, RS_normal (vs_to_es ves''
                    ++ [::AI_local m (Build_frame (rev ves' ++ zs) i) [::AI_basic (BI_block (Tf [::] t2s) es)]]))
            else (hs, s, f, crash_error)
        | FC_func_host (Tf t1s t2s) cl' =>
            let: n := length t1s in
            let: m := length t2s in
            if length ves >= n
            then
            let: (ves', ves'') := split_n ves n in
            match host_application_impl hs s (Tf t1s t2s) cl' (rev ves') with
            | (hs', Some (s', rves)) =>
                (hs', s', f, RS_normal (vs_to_es ves'' ++ (result_to_stack rves)))
            | (hs', None) => (hs', s, f, RS_normal (vs_to_es ves ++ [::AI_invoke a]))
            end
            else (hs, s, f, crash_error)
        end
      | None => (hs, s, f, crash_error)
      end
    | AI_label ln les es =>
      if es_is_trap es
      then (hs, s, f, RS_normal (vs_to_es ves ++ [::AI_trap]))
      else
        if const_list es
        then (hs, s, f, RS_normal (vs_to_es ves ++ es))
        else
          let: (hs', s', f', res) := run_step_with_fuel fuel d (hs, s, f, es) in
          match res with
          | RS_break 0 bvs =>
            if length bvs >= ln
            then (hs', s', f', RS_normal ((vs_to_es ((take ln bvs) ++ ves)) ++ les))
            else (hs', s', f', crash_error)
          | RS_break (n.+1) bvs => (hs', s', f', RS_break n bvs)
          | RS_return rvs => (hs', s', f', RS_return rvs)
          | RS_normal es' =>
            (hs', s', f', RS_normal (vs_to_es ves ++ [::AI_label ln les es']))
          | RS_crash error => (hs', s', f', RS_crash error)
          end
    | AI_local ln lf es =>
      if es_is_trap es
      then (hs, s, f, RS_normal (vs_to_es ves ++ [::AI_trap]))
      else
        if const_list es
        then
          if length es == ln
          then (hs, s, f, RS_normal (vs_to_es ves ++ es))
          else (hs, s, f, crash_error)
        else
          let: (hs', s', f', res) := run_step_with_fuel fuel d (hs, s, lf, es) in
          match res with
          | RS_return rvs =>
            if length rvs >= ln
            then (hs', s', f, RS_normal (vs_to_es (take ln rvs ++ ves)))
            else (hs', s', f, crash_error)
          | RS_normal es' =>
            (hs', s', f, RS_normal (vs_to_es ves ++ [::AI_local ln f' es']))
          | RS_crash error => (hs', s', f, RS_crash error)
          | RS_break _ _ => (hs', s', f, crash_error)
          end
    | AI_trap => (hs, s, f, crash_error)
    end
  end.

(** Enough fuel so that [run_one_step] does not run out of exhaustion. **)
Definition run_one_step_fuel : administrative_instruction -> nat.
Proof.
  move=> es. induction es using administrative_instruction_rect';
    let rec aux v :=
      lazymatch goal with
      | F : TProp.Forall _ _ |- _ =>
        apply TProp.max in F;
        move: F;
        let n := fresh "n" in
        move=> n;
        aux (n + v)
      | |- _ => exact (v.+1)
      end in
    aux (1 : nat).
Defined.

(** Enough fuel so that [run_step] does not run out of exhaustion. **)
Definition run_step_fuel (cfg : config_tuple) : nat :=
  let: (hs, s, f, es) := cfg in
  1 + List.fold_left max (List.map run_one_step_fuel es) 0.

Definition run_step (d : depth) (cfg : config_tuple) : res_tuple :=
  run_step_with_fuel (run_step_fuel cfg) d cfg.

Fixpoint run_v (fuel : fuel) (d : depth) (cfg : config_tuple) : ((host_state * store_record * res)%type) :=
  let: (hs, s, f, es) := cfg in
  match fuel with
  | 0 => (hs, s, R_crash C_exhaustion)
  | fuel.+1 =>
    if es_is_trap es
    then (hs, s, R_trap)
    else
      if const_list es
      then (hs, s, R_value (fst (split_vals_e es)))
      else
        let: (hs', s', f', res) := run_step d (hs, s, f, es) in
        match res with
        | RS_normal es' => run_v fuel d (hs', s', f', es')
        | RS_crash error => (hs', s', R_crash error)
        | _ => (hs', s', R_crash C_error)
        end
  end.

End Host_func.
