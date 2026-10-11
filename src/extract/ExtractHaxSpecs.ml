module F = Format

module Helpers = struct
  (** Emit [words] separated by breakable spaces *)
  let emit_words (fmt : F.formatter) (words : string list) : unit =
    List.iteri
      (fun i w ->
        if i > 0 then F.pp_print_space fmt ();
        F.pp_print_string fmt w)
      words

  (** Emit a pre/post condition function declaration. [extract_fun_decl] emits
      its own leading break, so we add no trailing separator here. *)
  let emit_cond (ctx : ExtractBase.extraction_ctx) (fmt : F.formatter)
      (f : Pure.fun_decl) : unit =
    Extract.extract_fun_decl ctx fmt ExtractBase.SingleNonRec false f

  (** Run [k] on its own line inside an [hovbox] *)
  let line (fmt : F.formatter) (k : unit -> unit) : unit =
    F.pp_print_cut fmt ();
    F.pp_open_hovbox fmt 0;
    k ();
    F.pp_close_box fmt ()

  (** Wrap [k] in a Hoare-triple postcondition delimiter [⦃ … ⦄]. *)
  let emit_wp (fmt : F.formatter) (k : unit -> unit) : unit =
    Extract.emit_delim fmt "⦃" k "⦄"

  (** Emit [<name> <generics> <args>] — an application head applied to its
      generic and value arguments (caller controls the surrounding box). This is
      for [<fn>.spec], which is synthesized at extraction time and thus has no
      declaration to point at. *)
  let emit_app span ctx fmt explicit generics args (name : string) =
    F.pp_print_string fmt name;
    (* Generic args, matching the head's generic binders. *)
    ExtractTypes.extract_generic_args span ctx fmt Pure.TypeDeclId.Set.empty
      ~explicit:(Some explicit) generics;
    List.iter
      (fun te ->
        F.pp_print_space fmt ();
        Extract.extract_texpr span ctx fmt ~inside:true ~inside_do:false te)
      args

  (** The head of an application of the local function [id] to [generics]. *)
  let fun_head (id : Pure.FunDeclId.id) generics (ty : Pure.ty) : Pure.texpr =
    let id = Pure.FunOrOp (Fun (FromLlbc (FunId id, None))) in
    { e = Qualif { id; generics }; ty }

  (** The arguments passed for the input patterns of a function. Unit inputs are
      [_] (see [unit_vars_to_unit]): we pass them as [()]. *)
  let input_args span (inputs : Pure.tpat list) : Pure.texpr list =
    List.map
      (fun (p : Pure.tpat) ->
        match PureUtils.tpat_to_texpr span p with
        | Some e -> e
        | None when p.ty = PureUtils.mk_unit_ty -> PureUtils.mk_unit_texpr
        | None -> [%internal_error] span)
      inputs

  (** The generics to pass to a pre/post condition [cond], from the [generics]
      of the function it describes. The types and const generics match, but the
      trait clauses may not:
      - their order differs: [cond] has the clauses of a trait method's own
        generics first, the method has them last;
      - for [trait T<U> where U: Clone], [cond] has a clause [U: Clone], which
        the method reaches through its [Self: T<U>] clause.

      - for [trait B: A], [cond] has clauses [Self_: A] and [Self_: B]: hax-lib
        adds the (transitive) supertraits as bounds of the conditions, which the
        method reaches through its [Self: B] clause.

      We look up each clause of [cond] among the trait refs of [generics] and
      their transitive parent clauses, after expressing its generics in terms of
      [generics].

      Not supported yet: a supertrait with associated types. Charon turns them
      into type parameters of [cond] that the method does not have. *)
  let cond_generics span (ctx : ExtractBase.extraction_ctx)
      (generics : Pure.generic_args) (cond : Pure.fun_decl) : Pure.generic_args
      =
    let params = cond.signature.generics in
    (* [tr] and its transitive parent clauses *)
    let rec with_parents (tr : Pure.trait_ref) : Pure.trait_ref list =
      let decl_ref = tr.trait_decl_ref in
      match
        Pure.TraitDeclId.Map.find_opt decl_ref.trait_decl_id
          ctx.trans_trait_decls
      with
      | None -> [ tr ]
      | Some d ->
          let subst =
            PureUtils.make_subst_from_generics_for_trait d.generics tr.trait_id
              decl_ref.decl_generics
          in
          let parent (c : Pure.trait_param) : Pure.trait_ref =
            {
              trait_id = ParentClause (tr.trait_id, d.def_id, c.clause_id);
              trait_decl_ref =
                {
                  trait_decl_id = c.trait_id;
                  decl_generics =
                    PureUtils.generic_args_substitute subst c.generics;
                };
            }
          in
          tr
          :: List.concat_map (fun c -> with_parents (parent c)) d.parent_clauses
    in
    let available = List.concat_map with_parents generics.trait_refs in
    [%cassert] span
      (List.length params.types = List.length generics.types
      && List.length params.const_generics = List.length generics.const_generics
      )
      "A pre/post condition does not have the same type and const generic \
       parameters as its function (e.g. a supertrait of the method's trait has \
       associated types)";
    let subst : PureUtils.subst =
      {
        ty_subst = PureUtils.make_type_subst params.types generics.types;
        cg_subst =
          PureUtils.make_const_generic_subst params.const_generics
            generics.const_generics;
        (* The generics of a clause mention no other clause *)
        tr_subst = (fun _ -> UnknownTrait "clause of a pre/post condition");
        tr_self = UnknownTrait "Self";
      }
    in
    let find (c : Pure.trait_param) : Pure.trait_ref =
      let decl_ref : Pure.trait_decl_ref =
        {
          trait_decl_id = c.trait_id;
          decl_generics = PureUtils.generic_args_substitute subst c.generics;
        }
      in
      match
        List.find_opt
          (fun (tr : Pure.trait_ref) -> tr.trait_decl_ref = decl_ref)
          available
      with
      | Some tr -> tr
      | None ->
          [%craise] span
            "Could not find an instance for a trait clause of a pre/post \
             condition"
    in
    { generics with trait_refs = List.map find params.trait_clauses }

  (** Emit [(<cond> <generics> <args>).holds] for a fn [f]. *)
  let emit_holds span ctx fmt generics args (f : Pure.fun_decl) =
    let generics = cond_generics span ctx generics f in
    let head = fun_head f.def_id generics f.signature.output in
    F.pp_open_hovbox fmt 0;
    F.pp_print_string fmt "(";
    Extract.extract_App span ctx fmt ~inside:false ~inside_do:false head args
      f.signature.output;
    F.pp_print_string fmt ").holds";
    F.pp_close_box fmt ()
end

open Helpers

(** Emit the proof of a spec/theorem as [:= by <tactic>]. *)
let emit_proof fmt (p : HaxSpecs.proof) =
  let tactic =
    match p with
    | Admitted -> "sorry"
  in
  F.pp_print_string fmt (":= by " ^ tactic)

(** Emit the pre/post condition function declarations, if present. *)
let emit_conditions ctx fmt ~pre ~post =
  Option.iter (emit_cond ctx fmt) pre;
  Option.iter (emit_cond ctx fmt) post

(** {1 Names}

    The contract of [<fn>] generates [<fn>.pre], [<fn>.post], [<fn>.spec] and
    [<fn>.spec.proof]. The contract of a method [<m>] of a trait [<Trait>]
    generates [<Trait>.<m>.pre] and [<Trait>.<m>.post]. *)

(** The registered name of [parent] *)
let registered_fun_name (ctx : ExtractBase.extraction_ctx)
    (parent : Pure.fun_decl) : string =
  ExtractBase.ctx_get_raw (Some parent.item_meta.span)
    (FunId (FromLlbc (FunId parent.def_id, parent.loop_id)))
    ctx

(** [<fn>.<suffix>] *)
let cond_name (parent_name : string) (suffix : string) : string =
  ExtractBuiltin.flatten_name [ parent_name; suffix ]

let spec_name (parent_name : string) : string =
  ExtractBuiltin.flatten_name [ parent_name; "spec" ]

let proof_name (parent_name : string) : string =
  ExtractBuiltin.flatten_name [ spec_name parent_name; "proof" ]

(** The names of the conditions [pre] and [post] of [parent_name] *)
let cond_names (parent_name : string) ~(pre : Pure.fun_decl option)
    ~(post : Pure.fun_decl option) : (Pure.fun_decl * string) list =
  let cond suffix (f : Pure.fun_decl option) =
    Option.map (fun f -> (f, cond_name parent_name suffix)) f
  in
  List.filter_map Fun.id [ cond "pre" pre; cond "post" post ]

(** The names of the conditions, spec and proof of [parent] *)
let generated_names (parent_name : string)
    ({ pre; post; _ } : HaxSpecs.function_spec) :
    (Pure.fun_decl * string) list * string * string =
  ( cond_names parent_name ~pre ~post,
    spec_name parent_name,
    proof_name parent_name )

(** Lookup the function a spec is about *)
let lookup_parent (ctx : ExtractBase.extraction_ctx) (fn : Pure.FunDeclId.id) :
    Pure.fun_decl option =
  Option.map
    (fun (ft : TranslateCore.pure_fun_translation) -> ft.f)
    (Pure.FunDeclId.Map.find_opt fn ctx.trans_funs)

(** Register a generated name; also return whether it clashes with a name
    registered before. *)
let add_generated_name (span : Meta.span) (id : ExtractBase.id) (name : string)
    ((ctx, clash) : ExtractBase.extraction_ctx * bool) :
    ExtractBase.extraction_ctx * bool =
  let clash = clash || ExtractBase.ctx_name_is_bound name ctx in
  (ExtractBase.ctx_add span id name ctx, clash)

(** Register the names of conditions, under the ids of their fns *)
let register_conds span (conds : (Pure.fun_decl * string) list)
    (acc : ExtractBase.extraction_ctx * bool) :
    ExtractBase.extraction_ctx * bool =
  List.fold_left
    (fun acc ((f : Pure.fun_decl), name) ->
      add_generated_name span (FunId (FromLlbc (FunId f.def_id, None))) name acc)
    acc conds

(** Warn that the contract of an untranslated item is dropped. We use the span
    of the LLBC item [item_meta], if found, and [opt_span] otherwise. *)
let warn_untranslated (ctx : ExtractBase.extraction_ctx) opt_span
    (item_meta : Types.item_meta option) (kind : string) (id : string) =
  let span, name =
    match item_meta with
    | Some m -> (Some m.span, TranslateCore.name_to_string ctx.trans_ctx m.name)
    | None -> (opt_span, id)
  in
  [%warn_opt_span] span
    (Printf.sprintf
       "hax-specs: dropping the contract of %s `%s`: the %s was not translated"
       kind name kind)

(** Register the names of the conditions and of the spec. Must be called after
    registering the crate items. Also return whether one of them clashes. Warns
    about the specs of untranslated items: {!emit_spec} skips them. *)
let register_spec_names (ctx : ExtractBase.extraction_ctx)
    (spec_id : Spec.SpecId.id) (s : HaxSpecs.spec) (opt_span : Meta.span option)
    : ExtractBase.extraction_ctx * bool =
  match s with
  | FunctionSpec fspec -> (
      match lookup_parent ctx fspec.fn with
      | None ->
          warn_untranslated ctx opt_span
            (Option.map
               (fun (f : LlbcAst.fun_decl) -> f.item_meta)
               (Pure.FunDeclId.Map.find_opt fspec.fn
                  ctx.trans_ctx.crate.fun_decls))
            "function"
            (Pure.FunDeclId.to_string fspec.fn);
          (ctx, false)
      | Some parent ->
          let span = parent.item_meta.span in
          let conds, spec, _ =
            generated_names (registered_fun_name ctx parent) fspec
          in
          (ctx, false) |> register_conds span conds
          |> add_generated_name span (SpecId spec_id) spec)
  | TraitSpec { trait_decl; methods } -> (
      match Pure.TraitDeclId.Map.find_opt trait_decl ctx.trans_trait_decls with
      | None ->
          warn_untranslated ctx opt_span
            (Option.map
               (fun (d : LlbcAst.trait_decl) -> d.item_meta)
               (Pure.TraitDeclId.Map.find_opt trait_decl
                  ctx.trans_ctx.crate.trait_decls))
            "trait"
            (Pure.TraitDeclId.to_string trait_decl);
          (ctx, false)
      | Some d ->
          let span = d.item_meta.span in
          let get id = ExtractBase.ctx_get_raw (Some span) id ctx in
          let trait_name = get (TraitDeclId trait_decl) in
          List.fold_left
            (fun acc ({ method_id; pre; post } : HaxSpecs.method_spec) ->
              let method_name = get (TraitMethodId (trait_decl, method_id)) in
              register_conds span
                (cond_names
                   (ExtractBuiltin.flatten_name [ trait_name; method_name ])
                   ~pre ~post)
                acc)
            (ctx, false) methods)

(** Same as {!register_spec_names}, for a proof obligation *)
let register_obligation_names (ctx : ExtractBase.extraction_ctx)
    (proof_id : Spec.ProofId.id) (o : HaxSpecs.obligation) :
    ExtractBase.extraction_ctx * bool =
  match o with
  | FunctionContract { spec = fspec; _ } -> (
      match lookup_parent ctx fspec.fn with
      | None -> (ctx, false)
      | Some parent ->
          add_generated_name parent.item_meta.span (ProofObligationId proof_id)
            (proof_name (registered_fun_name ctx parent))
            (ctx, false))
  | ImplLawful _ -> (* Not produced yet *) (ctx, false)

(** Emits the spec statement — the body of [def foo.spec … : Prop :=] (the
    [theorem foo.spec.proof … := by sorry] wrapper is the obligation, emitted
    separately):
    {[
      (foo.pre args).holds →
      ⦃ ⌜ True ⌝ ⦄
      foo args
      ⦃ ⇓ res => ⌜ (foo.post args res).holds ⌝ ⦄
    ]} *)
let emit_statement ctx fmt span (fn : Pure.FunDeclId.id) generics output_ty
    arg_texprs res_id ~(pre : Pure.fun_decl option)
    ~(post : Pure.fun_decl option) =
  let open ExtractBase in
  (* Register the postcondition's result variable *)
  let ctx, res_name = ctx_add_var span "res" res_id ctx in
  let res_texpr : Pure.texpr = { e = FVar res_id; ty = output_ty } in
  let emit_holds = emit_holds span ctx fmt generics in
  let emit_pure k = Extract.emit_delim fmt "⌜" k "⌝" in

  (* Optional pre-hypothesis: [(<fn>.pre <args>).holds →]. *)
  (match pre with
  | None -> ()
  | Some pre_fn ->
      line fmt (fun () ->
          emit_holds arg_texprs pre_fn;
          F.pp_print_space fmt ();
          F.pp_print_string fmt "→"));

  (* The (trivial) triple precondition. *)
  line fmt (fun () ->
      emit_wp fmt (fun () -> emit_pure (fun () -> F.pp_print_string fmt "True")));

  (* The real function application [<fn> <args>], via the standard printer. *)
  line fmt (fun () ->
      let head = fun_head fn generics output_ty in
      Extract.extract_App span ctx fmt ~inside:false ~inside_do:false head
        arg_texprs output_ty);

  (* The triple postcondition: [(<fn>.post <args> res).holds], or [True] when
     the function has no postcondition. *)
  line fmt (fun () ->
      emit_wp fmt (fun () ->
          emit_words fmt [ "⇓"; res_name; "=>" ];
          F.pp_print_space fmt ();
          emit_pure (fun () ->
              match post with
              | None -> F.pp_print_string fmt "True"
              | Some post_fn -> emit_holds (arg_texprs @ [ res_texpr ]) post_fn)))

(** Emit one [Spec.spec] entry *)
let emit_spec ctx fmt (s : HaxSpecs.spec) =
  let open ExtractBase in
  match s with
  | FunctionSpec { fn; pre; post } -> (
      match Pure.FunDeclId.Map.find_opt fn ctx.trans_funs with
      | None -> (* Reported by [register_spec_names] *) ()
      | Some ft ->
          (* Register the pre/post conditions in the (local) context *)
          let reg f_opt ctx =
            let some (f : Pure.fun_decl) =
              let trans : TranslateCore.pure_fun_translation =
                { f; loops = []; bodies = [] }
              in
              {
                ctx with
                trans_funs =
                  Pure.FunDeclId.Map.add f.def_id trans ctx.trans_funs;
              }
            in
            Option.fold ~some ~none:ctx f_opt
          in
          let ctx = ctx |> reg pre |> reg post in
          let parent = ft.f in
          let span = parent.item_meta.span in
          let sg = parent.signature in
          let generics = PureUtils.generic_args_of_params sg.generics in

          (* Open the parent's body binders *)
          let _, fresh_fvar_id = Pure.FVarId.fresh_stateful_generator () in
          let parent =
            {
              parent with
              body =
                Option.map
                  (fun b ->
                    snd (PureUtils.open_all_fun_body fresh_fvar_id span b))
                  parent.body;
            }
          in
          let arg_texprs =
            match parent.body with
            | None -> []
            | Some { inputs; _ } -> input_args span inputs
          in
          (* Fresh result-var id, from the body generator so it can't clash. *)
          let res_id = fresh_fvar_id () in

          (* Blank line before the entry. *)
          F.pp_print_break fmt 0 0;

          emit_conditions ctx fmt ~pre ~post;

          (* Spec definition header: [def <fn>.spec <binders> : Prop :=] *)
          F.pp_print_break fmt 0 0;
          F.pp_open_vbox fmt 0;
          F.pp_open_vbox fmt ctx.indent_incr;
          F.pp_open_hovbox fmt ctx.indent_incr;
          (match fun_decl_kind_to_qualif SingleNonRec with
          | Some qualif ->
              F.pp_print_string fmt qualif;
              F.pp_print_space fmt ()
          | None -> ());
          F.pp_print_string fmt
            (escape_name (spec_name (registered_fun_name ctx parent)));
          (* Generic + value binders via the standard param extractor. *)
          let space = ref false in
          let _, ctx, _ = Extract.extract_fun_parameters space ctx fmt parent in
          ExtractTypes.insert_req_space fmt space;
          F.pp_print_string fmt ": Prop :=";
          F.pp_close_box fmt ();

          (* Statement shape (the def body). *)
          emit_statement ctx fmt span fn generics sg.output arg_texprs res_id
            ~pre ~post;
          F.pp_close_box fmt ();
          (* inner vbox *)
          F.pp_close_box fmt ();
          (* outer vbox *)
          F.pp_print_cut fmt ())
  | TraitSpec { trait_decl; _ }
    when not (Pure.TraitDeclId.Map.mem trait_decl ctx.trans_trait_decls) ->
      (* Reported by [register_spec_names] *) ()
  | TraitSpec { methods; _ } ->
      (* The conditions of the annotated methods *)
      if methods <> [] then (
        (* Blank line before the entry. *)
        F.pp_print_break fmt 0 0;
        List.iter
          (fun ({ pre; post; _ } : HaxSpecs.method_spec) ->
            emit_conditions ctx fmt ~pre ~post)
          methods)

(** Emit one [HaxSpecs.obligation] entry as the proof obligation that discharges
    a spec's statement of correctness:
    {[
      theorem foo.spec.proof args : foo.spec args := by sorry
    ]}
    No attribute is emitted: registering the obligation with [mvcgen] (via
    [@[spec]]) is left to the user, who decides which specs to feed it. *)
let emit_obligation ctx fmt (o : HaxSpecs.obligation) =
  let open ExtractBase in
  match o with
  | FunctionContract { spec = { fn; _ }; proof } -> (
      match Pure.FunDeclId.Map.find_opt fn ctx.trans_funs with
      | None -> (* Reported by [register_spec_names] *) ()
      | Some ft ->
          let parent = ft.f in
          let span = parent.item_meta.span in
          let sg = parent.signature in
          let explicit = sg.explicit_info in
          let generics = PureUtils.generic_args_of_params sg.generics in
          let parent_name = registered_fun_name ctx parent in

          (* Open the parent's body binders *)
          let _, fresh_fvar_id = Pure.FVarId.fresh_stateful_generator () in
          let parent =
            {
              parent with
              body =
                Option.map
                  (fun b ->
                    snd (PureUtils.open_all_fun_body fresh_fvar_id span b))
                  parent.body;
            }
          in
          let arg_texprs =
            match parent.body with
            | None -> []
            | Some { inputs; _ } -> input_args span inputs
          in

          (* Blank line before the entry. *)
          F.pp_print_break fmt 0 0;

          (* Box layout (brackets = boxes):
             [ [theorem name] binders : [statement] ]  [:= by sorry]
             The outer [hvbox] keeps the whole theorem on one line if it fits;
             otherwise [:= by sorry] breaks onto its own line first, and only if
             the statement box itself still overflows do the binders/type wrap. *)
          F.pp_open_hvbox fmt ctx.indent_incr;
          (* The theorem statement: [theorem name binders : <type>]. *)
          F.pp_open_hovbox fmt ctx.indent_incr;
          F.pp_print_string fmt "theorem";
          F.pp_print_space fmt ();
          F.pp_print_string fmt (escape_name (proof_name parent_name));
          (* Generic + value binders via the standard param extractor. *)
          let space = ref false in
          let _, ctx, _ = Extract.extract_fun_parameters space ctx fmt parent in
          ExtractTypes.insert_req_space fmt space;
          F.pp_print_string fmt ":";
          F.pp_print_space fmt ();
          (* The statement of correctness, in its own box:
             [<fn>.spec <generics> <args>]. *)
          F.pp_open_hovbox fmt 0;
          emit_app span ctx fmt explicit generics arg_texprs
            (escape_name (spec_name parent_name));
          F.pp_close_box fmt ();
          F.pp_close_box fmt ();
          (* statement hovbox *)
          F.pp_print_space fmt ();
          emit_proof fmt proof;
          F.pp_close_box fmt ();
          (* outer hvbox *)
          F.pp_print_cut fmt ())
  | ImplLawful _ -> (* Not produced yet *) ()
