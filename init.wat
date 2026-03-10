  ;; ────────────────────────────────────────────────────────────────
  ;; $init – Bootstrap: create all core primitives + immediate words
  ;; ────────────────────────────────────────────────────────────────
  (func $init
    ;; ── Primitives (segment 00 = code, target = negative opcode) ─────
    ;; opcode     name       immediate?   target (opcode)
    (call $create-str "dup"     3  (i32.const 0b00000100) (i32.const -2) (i32.const 0))   ;; DUP
    (call $create-str "drop"    4  (i32.const 0b00000000) (i32.const -3) (i32.const 0))
    (call $create-str "swap"    4  (i32.const 0b00000000) (i32.const -4) (i32.const 0))
    (call $create-str "+"       1  (i32.const 0b00000000) (i32.const -5) (i32.const 0))
    (call $create-str "-"       1  (i32.const 0b00000000) (i32.const -6) (i32.const 0))
    (call $create-str "*"       1  (i32.const 0b00000000) (i32.const -7) (i32.const 0))
    (call $create-str "/"       1  (i32.const 0b00000000) (i32.const -8) (i32.const 0))
    (call $create-str "f+"      2  (i32.const 0b00000000) (i32.const -9) (i32.const 0))
    (call $create-str "f-"      2  (i32.const 0b00000000) (i32.const -10)(i32.const 0))
    (call $create-str "f*"      2  (i32.const 0b00000000) (i32.const -11)(i32.const 0))
    (call $create-str "f/"      2  (i32.const 0b00000000) (i32.const -12)(i32.const 0))
    (call $create-str "@"       1  (i32.const 0b00000000) (i32.const -13)(i32.const 0))
    (call $create-str "!"       1  (i32.const 0b00000000) (i32.const -14)(i32.const 0))
    (call $create-str "emit"    4  (i32.const 0b00000000) (i32.const -18)(i32.const 0))
    (call $create-str "="       1  (i32.const 0b00000000) (i32.const -20)(i32.const 0))
    (call $create-str ">"       1  (i32.const 0b00000000) (i32.const -21)(i32.const 0))
    (call $create-str "<"       1  (i32.const 0b00000000) (i32.const -22)(i32.const 0))
    (call $create-str "i"       1  (i32.const 0b00000100) (i32.const -25)(i32.const 0))   ;; immediate because used inside loops

    ;; ── Control structure immediates (compile branches etc.) ─────────
    ;; These compile code at compile-time and are immediate

    ;; IF / THEN / ELSE
    (call $create-str "if"      2  (i32.const 0b00000101) (i32.const 0) (i32.const 0))   ;; immediate + compile-only-ish
    (call $create-str "else"    4  (i32.const 0b00000101) (i32.const 0) (i32.const 0))
    (call $create-str "then"    4  (i32.const 0b00000101) (i32.const 0) (i32.const 0))

    ;; DO / LOOP / +LOOP / I / J / LEAVE
    (call $create-str "do"      2  (i32.const 0b00000101) (i32.const 0) (i32.const 0))
    (call $create-str "loop"    4  (i32.const 0b00000101) (i32.const 0) (i32.const 0))
    (call $create-str "+loop"   5  (i32.const 0b00000101) (i32.const 0) (i32.const 0))
    (call $create-str "j"       1  (i32.const 0b00000101) (i32.const 0) (i32.const 0))
    (call $create-str "leave"   5  (i32.const 0b00000101) (i32.const 0) (i32.const 0))

    ;; ── Colon / Semicolon ────────────────────────────────────────────
    (call $create-str ":"       1  (i32.const 0b00000101) (i32.const 0) (i32.const 0))   ;; immediate
    (call $create-str ";"       1  (i32.const 0b00000101) (i32.const 0) (i32.const 0))   ;; immediate

    ;; ── Output helpers ───────────────────────────────────────────────
    (call $create-str "."       1  (i32.const 0b00000000) (i32.const 0) (i32.const 0))   ;; we'll define body later
    (call $create-str "cr"      2  (i32.const 0b00000000) (i32.const 0) (i32.const 0))
    (call $create-str "space"   5  (i32.const 0b00000000) (i32.const 0) (i32.const 0))
    (call $create-str "spaces"  6  (i32.const 0b00000000) (i32.const 0) (i32.const 0))

    ;; ────────────────────────────────────────────────────────────────
    ;; Now define the BODIES of the words that need code (not primitives)
    ;; ────────────────────────────────────────────────────────────────

    ;; Example: define "."  ( -- )   DUP EMIT-like logic or host call
    ;; In real system this would compile DUP 0BRANCH etc. – here stubbed

    ;; Real implementations would be added here as compiled sequences
    ;; or as colon definitions using the same interpreter
  )

  ;; Helper: create from string literal in memory (for bootstrap)
  (func $create-str (param $s i32) (param $len i32)
                    (param $flags i32) (param $target i32) (param $aux i32)
                    (result i32)
    (call $create
      (i32.add (global.get $DICT_BASE) (local.get $s))   ;; fake addr – adjust if you place strings elsewhere
      (local.get $len)
      (local.get $flags)
      (local.get $target)
      (local.get $aux)))
