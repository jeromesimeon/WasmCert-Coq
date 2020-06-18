# wasm_coq
WebAssembly (aka Wasm) formalisation in Coq, based on the offical formalisation (https://www.w3.org/TR/wasm-core-1/).
Our definitions and proofs draw from those given in the Isabelle mechanisation of Conrad Watt (https://www.isa-afp.org/entries/WebAssembly.html).

(C) J. Pichon, M. Bodin, R. Xiaojia, C. Watt 2019-2020 - see LICENSE.txt

This work is in progress, comprising WasmCert, a Coq-Specification of the Wasm operational semantics, and WasmRef, a Coq-representation of the Wasm pseudo-code standard which yields an OCAML interpreter. Our initial work used the definitions published in PLDI'17 and we are now adapting the definitions to Wasm 1.0., the specification as ratified by W35. 

# TODOs

- [x] Give core definitions of WasmCert and WasmRef.
- [x] Prove soundness result for WasmRef with respect to WasmCert.
- [x] Update the definition of WebAssembly's global store to match the 1.0 standard.
- [ ] Update the function frame and related definitions to match the 1.0 standard.
- [ ] Finish type soundness result.
- [ ] Link WasmCert to CompCert.
- [ ] Provide Iris Wasm.

This repository contains some experimental work on a binary parser and Iris integration. 

# Installation

The project comes with an `esy` packaging.

The following programs are assumed to be installed: `git`, `curl`, `m4`, and `autoconf`.
These programs are used to fetch and compile dependencies.

Installing `esy` itself can be done through `npm`.
It should then look like something like that:
```bash
sudo apt install npm git curl m4 autoconf
sudo npm install --global esy@latest # Tested with version 0.6.2 of esy.
```
Note that despite using `npm` to be installed, `esy` is not JavaScript-based.
If you prefer to avoid `npm` altogether, there are other ways to install `esy`: see <https://esy.sh/> for more information.

Once `esy` is installed, simply type `esy` to download and install the dependencies and compile everything.
Warning: compiling the dependencies requires having about 3 or 4 GB of RAM on your computer.
```bash
esy
```

Type `esy shell` to open a shell with the right compilation environment.
You can also type `esy emacs theories/wasm.v` to open Emacs with the right environment (assuming that Emacs is installed with Proof General in your system).
Note that `emacs theories/wasm.v` (without the `esy` prefix) will open Emacs without setting the local dependencies: doing so will likely prevent `coq` from finding the needed dependencies.

To use CoqIDE in this developpment, you first need to install its system dependencies (these are probably already installed on your system if you are using CoqIDE):
```bash
sudo apt install libcairo2-dev libexpat1-dev libgtk-3-dev libgtksourceview-3.0-dev
```
Then, replace the line `devDependencies: {},` by `devDependencies: {"@opam/coqide": "*"}` in [package.json](./package.json), and run `esy` again.
Typing `esy coqide theories/wasm.v` should now work.

To use VSCoq in this development, a [.vscode/settings.json](.vscode/settings.json) file is generated during the compilation: running `esy` should set up all required variables.

