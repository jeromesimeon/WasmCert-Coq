(** Extraction to OCaml. **)
(* (C) M. Bodin, J. Pichon - see LICENSE.txt *)

From Coq Require Extraction.

From Wasm Require Import
  datatypes_properties
  binary_format_parser
  instantiation_func
  interpreter_ctx
  type_checker
  pp
  host
.

From Coq Require Import
  extraction.ExtrOcamlBasic
  extraction.ExtrOcamlString.

Extraction Language OCaml.

Extraction "extract"
  run_parse_module
  Instantiation_func_extract
  Interpreter_ctx_extract
  PP
  DummyHost
  empty_frame
  .
