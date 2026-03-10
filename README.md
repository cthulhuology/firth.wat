# Firth.wat – A minimal Forth system in raw WebAssembly Text Format

**Firth** is a compact, from-scratch implementation of a Forth virtual machine and interpreter written entirely in **WebAssembly Text Format** (.wat). It follows a classic indirect-threaded model with a minimal instruction set, separate memory regions (Harvard-like architecture), relative addressing for relocatability, and support for both integer and floating-point arithmetic.

The project is split into small, readable modules so you can study, modify or extend individual parts (VM dispatch, dictionary, bootstrapping words, etc.).

## Status

Very early / experimental (March 2026)  
- Core VM loop working  
- Basic integer + float primitives  
- Dictionary with fixed-size entries + deduplicated strings  
- Tokenized source segment for future SEE / decompilation  
- Scratch-buffer compilation for every line → control structures (`if`/`then`/`do`/`loop`) work in interpret mode  
- No persistent `STATE` variable – everything compiles to temporary code then executes immediately  

Not yet ANS compliant, no full file I/O or floating-point stack separation, no optimizing compiler.

## Features

- Indirect-threaded VM with ~25 core opcodes (LIT, DUP, DROP, SWAP, +/−/*//, F+/F−/F*/F/, @/!, BRANCH/0BRANCH, EXIT, EMIT, =/>/<, (DO)/(LOOP), I, etc.)
- Separate memory regions: dictionary, data, code, strings, source (all relative offsets → relocatable in theory)
- Deduplicated string interning (names stored once)
- Tokenized source storage (enables future `SEE`, `WH` / where-used, editor integration)
- Line-by-line compile-to-scratch → execute model (enables full control flow in interactive mode)
- MIT licensed – hack freely

## Files

| File              | Purpose                                                                 |
|-------------------|-------------------------------------------------------------------------|
| `vm.wat`          | Inner interpreter loop (NEXT), primitive implementations, stack ops     |
| `dict.wat`        | Dictionary array (16-byte fixed entries), $find, $intern, $create       |
| `init.wat`        | Bootstrap: creates primitive words + core immediates (: ; IF THEN DO LOOP etc.) |
| `firth.wat`       | Main module – imports, memory layout, outer interpreter, $run           |
| `test_firth.wat`  | Basic test words / examples (can be loaded or used for wat2wasm testing)|

## Building & Running

Requires:
- `wat2wasm` (from wabt toolkit)  
- A Wasm runtime with simple JS imports: `shell.emit(i32)` and `shell.read(addr, maxlen) → i32`

Typical workflow:

```bash
# Combine modules if desired (or just use firth.wat as entry point)
wat2wasm firth.wat -o firth.wasm

# Run in wasmtime (with WASI-like host or custom JS glue)
wasmtime firth.wasm
# or load in browser / node with appropriate imports
