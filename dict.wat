(module
  ;; ──────────────────────────────────────────────────────────────────────
  ;; Memory layout (Harvard-style, all pointers relative to their base)
  ;; ──────────────────────────────────────────────────────────────────────
  (memory (export "memory") 16)  ;; 1 MiB total – room for ~4000 dict entries + plenty of strings/source

  (global $DICT_BASE     i32 (i32.const 0x00000))  ;; dictionary array (16-byte entries)
  (global $DATA_BASE     i32 (i32.const 0x10000))  ;; variables, stacks, HERE
  (global $CODE_BASE     i32 (i32.const 0x20000))  ;; threaded code
  (global $STRINGS_BASE  i32 (i32.const 0x30000))  ;; deduplicated name strings (len-prefixed)
  (global $SOURCE_BASE   i32 (i32.const 0x40000))  ;; tokenized source: array of i32 name_offsets

  ;; ──────────────────────────────────────────────────────────────────────
  ;; Dictionary / strings / source allocation pointers (relative)
  ;; ──────────────────────────────────────────────────────────────────────
  (global $dict_here    (mut i32) (i32.const 0))     ;; next free dictionary entry (bytes)
  (global $strings_here (mut i32) (i32.const 0))     ;; next free byte in strings segment
  (global $source_here  (mut i32) (i32.const 0))     ;; next free byte in source segment (always multiple of 4)

  ;; ──────────────────────────────────────────────────────────────────────
  ;; Helpers
  ;; ──────────────────────────────────────────────────────────────────────
  (func $memcpy (param $dst i32) (param $src i32) (param $len i32)
    (local $i i32)
    (loop $cp
      (if (i32.ge_u (local.get $i) (local.get $len)) (then (return)))
      (i32.store8 (i32.add (local.get $dst) (local.get $i))
                  (i32.load8_u (i32.add (local.get $src) (local.get $i))))
      (local.set $i (i32.add (local.get $i) (i32.const 1)))
      (br $cp)))

  (func $memcmp (param $a i32) (param $b i32) (param $len i32) (result i32)
    (local $i i32)
    (loop $m
      (if (i32.ge_u (local.get $i) (local.get $len)) (then (return (i32.const 1))))
      (if (i32.ne (i32.load8_u (i32.add (local.get $a) (local.get $i)))
                 (i32.load8_u (i32.add (local.get $b) (local.get $i))))
        (then (return (i32.const 0))))
      (local.set $i (i32.add (local.get $i) (i32.const 1)))
      (br $m)))

  ;; ──────────────────────────────────────────────────────────────────────
  ;; INTERN – deduplicated string storage (length-prefixed internally)
  ;; Returns offset to the length byte in STRINGS_BASE
  ;; ──────────────────────────────────────────────────────────────────────
  (func $intern (param $name_addr i32) (param $name_len i32) (result i32)
    (local $pos i32)
    (local $slen i32)
    (local.set $pos (i32.const 0))

    (loop $scan
      (if (i32.ge_u (local.get $pos) (global.get $strings_here))
        (then
          ;; not found → append
          (local.set $pos (global.get $strings_here))
          (i32.store8 (i32.add (global.get $STRINGS_BASE) (local.get $pos)) (local.get $name_len))
          (call $memcpy
            (i32.add (global.get $STRINGS_BASE) (i32.add (local.get $pos) (i32.const 1)))
            (local.get $name_addr)
            (local.get $name_len))
          (global.set $strings_here
            (i32.add (local.get $pos) (i32.add (i32.const 1) (local.get $name_len))))
          (return (local.get $pos))))

      (local.set $slen (i32.load8_u (i32.add (global.get $STRINGS_BASE) (local.get $pos))))
      (if (i32.eq (local.get $slen) (local.get $name_len))
        (then
          (if (call $memcmp
                (i32.add (global.get $STRINGS_BASE) (i32.add (local.get $pos) (i32.const 1)))
                (local.get $name_addr)
                (local.get $name_len))
            (then (return (local.get $pos))))))

      (local.set $pos (i32.add (local.get $pos) (i32.add (i32.const 1) (local.get $slen))))
      (br $scan)))

  ;; ──────────────────────────────────────────────────────────────────────
  ;; FIND – newest-first linear scan over dictionary array
  ;; Returns dictionary entry offset (relative to DICT_BASE) or -1
  ;; ──────────────────────────────────────────────────────────────────────
  (func $find (param $name_addr i32) (param $name_len i32) (result i32)
    (local $pos i32)
    (local.set $pos (i32.sub (global.get $dict_here) (i32.const 16)))  ;; start at newest entry

    (loop $search
      (if (i32.lt_s (local.get $pos) (i32.const 0))
        (then (return (i32.const -1))))

      ;; quick length filter
      (if (i32.eq
            (i32.load8_u (i32.add (global.get $DICT_BASE) (i32.add (local.get $pos) (i32.const 8))))
            (local.get $name_len))
        (then
          (if (call $name_matches (local.get $pos) (local.get $name_addr) (local.get $name_len))
            (then (return (local.get $pos))))))

      (local.set $pos (i32.sub (local.get $pos) (i32.const 16)))
      (br $search)))

  (func $name_matches (param $dict_pos i32) (param $input_addr i32) (param $len i32) (result i32)
    (local $str_off i32)
    (local.set $str_off (i32.load (i32.add (global.get $DICT_BASE) (i32.add (local.get $dict_pos) (i32.const 4)))))
    (if (i32.ne
          (i32.load8_u (i32.add (global.get $STRINGS_BASE) (local.get $str_off)))
          (local.get $len))
      (then (return (i32.const 0))))
    (call $memcmp
      (i32.add (global.get $STRINGS_BASE) (i32.add (local.get $str_off) (i32.const 1)))
      (local.get $input_addr)
      (local.get $len)))

  ;; ──────────────────────────────────────────────────────────────────────
  ;; IS_IMMEDIATE
  ;; ──────────────────────────────────────────────────────────────────────
  (func $is_immediate (param $entry i32) (result i32)
    (i32.and
      (i32.load8_u (i32.add (global.get $DICT_BASE) (i32.add (local.get $entry) (i32.const 9))))
      (i32.const 4)))  ;; bit 2 = immediate

  ;; ──────────────────────────────────────────────────────────────────────
  ;; CREATE – add a dictionary entry (16-byte record)
  ;; segment = 0..3 (low 2 bits of flags)
  ;; aux = source offset for colon definitions (or 0)
  ;; Returns the dictionary entry offset
  ;; ──────────────────────────────────────────────────────────────────────
  (func $create (param $name_addr i32) (param $name_len i32)
                (param $flags i32) (param $target i32) (param $aux i32)
                (result i32)  ;; dict entry offset
    (local $entry i32)
    (local $name_off i32)

    (local.set $name_off (call $intern (local.get $name_addr) (local.get $name_len)))
    (local.set $entry (global.get $dict_here))

    ;; target/ptr (relative to its segment)
    (i32.store
      (i32.add (global.get $DICT_BASE) (local.get $entry))
      (local.get $target))

    ;; name_offset (points to length byte in STRINGS_BASE)
    (i32.store
      (i32.add (global.get $DICT_BASE) (i32.add (local.get $entry) (i32.const 4)))
      (local.get $name_off))

    ;; name_len
    (i32.store8
      (i32.add (global.get $DICT_BASE) (i32.add (local.get $entry) (i32.const 8)))
      (local.get $name_len))

    ;; flags (segment in bits 0-1, immediate in bit 2, etc.)
    (i32.store8
      (i32.add (global.get $DICT_BASE) (i32.add (local.get $entry) (i32.const 9)))
      (local.get $flags))

    ;; aux (i32 – source segment offset for SEE)
    (i32.store
      (i32.add (global.get $DICT_BASE) (i32.add (local.get $entry) (i32.const 12)))
      (local.get $aux))

    (global.set $dict_here (i32.add (local.get $entry) (i32.const 16)))
    (local.get $entry))

  ;; ──────────────────────────────────────────────────────────────────────
  ;; SOURCE TOKEN APPEND (for tokenized source – used by editor and :)
  ;; Appends a name_offset (i32) to the current definition
  ;; ──────────────────────────────────────────────────────────────────────
  (func $source_append (param $name_off i32)
    (i32.store
      (i32.add (global.get $SOURCE_BASE) (global.get $source_here))
      (local.get $name_off))
    (global.set $source_here
      (i32.add (global.get $source_here) (i32.const 4))))

  ;; ──────────────────────────────────────────────────────────────────────
  ;; Example usage (how SEE / WH would start)
  ;; ──────────────────────────────────────────────────────────────────────
  ;; To implement SEE (word):
  ;;   entry = find(...)
  ;;   src_start = load i32 at entry+12
  ;;   loop: token = load i32 at SOURCE_BASE + src_start
  ;;         if token == -1 break
  ;;         print name of token (lookup or direct from strings)
  ;;         src_start += 4
  ;;
  ;; To implement WH (where-is token):
  ;;   name_off = intern(token)
  ;;   scan entire SOURCE_BASE … source_here looking for matching i32 values
  ;;   for each match, find which dictionary entry owns that source range (aux)

  ;; Initial dictionary is empty. Primitives / core words are added at runtime
  ;; with $create (name, len, flags | segment, code_offset_or_data_offset, source_aux)
)
