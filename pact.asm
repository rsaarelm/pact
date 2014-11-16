format ELF executable 3
entry start

include 'import32.inc'
interpreter '/lib/ld-linux.so.2'
needed 'libdl.so.2'
import dlopen, dlsym

   ;; Forthy stuff, based on the JonesForth tutorial.

   ;; Increment next word pointer at ESI and jump to the address that was
   ;; previously in ESI.
macro NEXT {
   lodsd
   jmp   dword [eax]
}

   ;; Push register to return stack
macro PUSHRSP reg {
   xchg ebp, esp
   push reg
   xchg ebp, esp
}

   ;; Pop into register from return stack
macro POPRSP reg {
   xchg ebp, esp
   pop reg
   xchg ebp, esp
}

macro ALIGN4 reg {
   add   reg, 3
   and   reg, -4
}

LATEST = 0

   ;; Define words. w is the internal string, sym is the one used in
   ;; assembler. They need to be different since all internal strings aren't
   ;; valid assembler labels. Stops just short of the codeword of the
   ;; definition.
macro word_header w, sym, flags = 0
{
local start, end, strlen
strlen = (end - start) - 1
   align 4
   name_#sym:
   dd    LATEST                 ; Back pointer
   db (strlen + flags) ; Name length and flags
start:
   db w
   db 0
end:
   align 4
sym:

LATEST = name_#sym
}

   ;; Define a native code word, the codeword just jumps straight into the
   ;; code that follows the word header.
macro defcode w, sym, flags = 0
{
   word_header w, sym, flags
   dd $+4
}

   ;; Define an interpreted word.
macro defword w, sym, flags = 0
{
   word_header w, sym, flags
   dd docol
}

   ;; Define a variable, a word that will push the variable's memory address
   ;; to stack.
macro defvar w, sym, flags, initial
{
   defcode w, sym, flags
   push  var_#sym
   NEXT
var_#sym: dd initial
}

   ;; Define a constant, a word that will push a value to stack.
macro defconst w, sym, flags, value
{
   defcode w, sym, flags
   push value
   NEXT
}

FLAG_IMMEDIATE = 0x80        ; Immediate word flag, put in size field
FLAG_HIDDEN = 0x20           ; Hidden word flag, put in size field
LENGTH_MASK = 0x1f

segment readable executable

   ;; The inner interpreter
docol:
   PUSHRSP esi
   add   eax, 4
   mov   esi, eax               ; Move start of code to ESI
   NEXT                         ; Go execute the word.


   ;; Main code
start:
   mov   ebp, RETURN_STACK_TOP  ; Initialize return stack
   mov   [var_s0], esp          ; Store data stack top in variable

   call  init_heap              ; Init data segment

   mov   eax, quit
   jmp   docol

cleanup:
   mov   eax, 1                 ; sys_exit
   xor   ebx,ebx                ; exit code
   int   0x80


segment readable writable executable
   ;; Define some native code words

   defcode "syscall3",syscall3
   pop   eax                    ; ID
   pop   edx                    ; param 3
   pop   ecx                    ; param 2
   pop   ebx                    ; param 1
   int   0x80
   NEXT

   defcode "syscall2",syscall2
   pop   eax                    ; ID
   pop   ecx                    ; param 2
   pop   ebx                    ; param 1
   int   0x80
   NEXT

   defcode "syscall1",syscall1
   pop   eax                    ; ID
   pop   ebx                    ; param 1
   int   0x80
   NEXT

   ;; Print a byte from the stack
   defcode "emit",emit
   pop   eax
   call  emit_code
   NEXT
emit_code:
   mov [.char], al
   mov   eax, 4                 ; sys_write
   mov   ebx, 1                 ; stdout
   mov   ecx, .char
   mov   edx, 1
   int   0x80
   ret
.char: rb 1

   ;; Read a byte from stdin into stack
   ;; XXX: Currently making a syscall for every byte, should use a buffer.
   defcode "key", key
   call  key_code_inner
   sub   esp, 4                 ; make room in stack
   mov   [esp], eax
   NEXT
key_code_inner:
   mov   eax, 3                 ; sys_read
   mov   ebx, 0                 ; stdin
   mov   ecx, INPUT_BUFFER      ; top of the stack for input
   mov   edx, 1
   int   0x80
   test  eax, eax               ; Exit program on EOF
   jbe   cleanup
   mov   eax, [INPUT_BUFFER]
   ret

   ;; Open a DLL lib
   ;; : dlopen ( flag name -- handle )
   defcode "dlopen", _dlopen
   call  [dlopen]
   add   esp, 8                 ; Arg cleanup
   push  eax
   NEXT

   ;; Load a function from a DLL lib
   ;; : dlsym ( name handle -- func )
   defcode "dlsym", _dlsym
   call  [dlsym]
   add   esp, 8                 ; Arg cleanup
   push  eax
   NEXT

   defcode "nativecall", nativecall
   pop   eax
   call  dword eax
   push  eax
   NEXT

   ;; Return from a colon word.
   defcode "exit", exit
   POPRSP esi
   NEXT

   ;; Exit the program
   defcode "bye", bye
   jmp   cleanup

   ;; Insert a debugger breakpoint
   defcode "*int3*", _int3
   int3
   NEXT

   ;; Read next word into stack as a literal
   defcode "lit", lit
   lodsd                        ; load literal pointed by esi into eax, increment esi
   push  eax
   NEXT

   defcode "execute", execute
   pop   eax
   jmp   dword [eax]

   ;; Memory access primitives

   ;; Read memory at address
   defcode "@", fetch
   pop   ebx                    ; address
   mov   eax, [ebx]
   push  eax
   NEXT

   ;; Write value to address
   defcode "!", _store
   pop   ebx                    ; address
   pop   eax                    ; value to store
   mov   [ebx], eax
   NEXT

   defcode "c@", fetchbyte
   xor   eax, eax
   pop   ebx
   mov   al, [ebx]
   push  eax
   NEXT

   defcode "c!", storebyte
   pop   ebx
   pop   eax
   mov   [ebx], al
   NEXT

   ;; Pop two stack values and push their sum back
   defcode "+", plus
   pop   eax                    ; Pop first value
   add   dword [esp], eax       ; Sum it to the second one
   NEXT

   defcode "*", _times
   pop   eax
   pop   ebx
   imul  eax, ebx
   push  eax
   NEXT

   defcode "-", minus
   pop   eax
   sub   dword [esp], eax
   NEXT

   defcode "/mod", divmod
   xor   edx, edx
   pop   ebx
   pop   eax
   idiv  ebx
   push  edx                    ; remainder
   push  eax                    ; quotient
   NEXT

   defcode "=", equ
   pop   eax
   pop   ebx
   cmp   eax, ebx
   sete  al
   movsx eax, al
   push  eax
   NEXT

   defcode "<0", lzero
;;   pop eax
;;   cwd                          ; move sign bit of eax into edx
;;   push edx
   pop   eax
   cmp   eax, 0
   jg    @f
   mov   eax, -1
   push  eax
   NEXT
@@:
   mov   eax, 0
   push  eax
   NEXT

   defcode "invert", invert
   not   DWORD [esp]
   NEXT

   defcode "and", _and
   pop   eax
   and   [esp], eax
   NEXT

   defcode "or", _or
   pop   eax
   or    [esp], eax
   NEXT

   defcode "xor", _xor
   pop   eax
   xor   [esp], eax
   NEXT

   ;; Offset the code word pointer by the amount in the word immediately
   ;; following 'branch'.
   defcode "branch", branch
   mov   esi, [esi]             ; ESI already points to the next word when we get here.
   NEXT

   ;; Like branch, but only branch if top of stack is 0.
   defcode "0branch", zbranch
   pop   eax
   test  eax, eax
   jz    @f                     ; If zero, do the same as branch
   lodsd                        ; Otherwise just consume the address and carry on
   NEXT
@@:
   mov   esi, [esi]
   NEXT

   ;; Push to return stack
   defcode ">r", tor
   pop   eax
   xchg  ebp, esp
   push  eax
   xchg  ebp, esp
   NEXT

   ;; Pop from return stack
   defcode "r>", fromr
   xchg  ebp, esp
   pop   eax
   xchg  ebp, esp
   push  eax
   NEXT

   ;; See top of return stack
   defcode "r@", atr
   mov   eax, [ebp]
   push  eax
   NEXT

   defcode "dup", _dup
   push  dword [esp]
   NEXT

   defcode "drop", drop
   pop   eax
   NEXT

   defcode "swap", swap
   pop   eax
   pop   ebx
   push  eax
   push  ebx
   NEXT

   defcode "over", over
   pop   eax
   pop   ebx
   push  ebx
   push  eax
   push  ebx
   NEXT

   ;; : rot ( a b c -- b c a )
   defcode "rot", rot
   pop   eax
   pop   ebx
   pop   ecx
   push  ebx
   push  eax
   push  ecx
   NEXT

   ;; : -rot ( a b c -- c a b )
   defcode "-rot", nrot
   pop   eax
   pop   ebx
   pop   ecx
   push  eax
   push  ecx
   push  ebx
   NEXT

   ;; ***
   ;; Obligatory primitive word definitions end here
   ;; The rest of the stuff should be definable with earlier words.
   ;; ***

   ;; To get a parser going we need some words we can define in forth. Since
   ;; we can't parse them before using them to build a parser, we'll just type
   ;; the bytecode straight into the kernel here. Immediate words aren't
   ;; available, so their effects will need to be written out, otherwise it's
   ;; possible to write quite idiomatic Forth code in assembler.

   defword "=0", zequ
   dd    lit, 0, equ, exit

   defword "not", _not
   dd    zequ, exit

   defword "<", lt
   dd    minus, lzero, exit

   defword "<=", lte
   dd    minus, decr, lzero, exit

   defword "/", _div
   dd    divmod, swap, drop, exit

   ;; Experimental. Jump to the current word's start instead of recursing to
   ;; stack, doesn't consume stack.
   defword "tail-recurse", tail_recurse, FLAG_IMMEDIATE
   dd    lit, branch, comma, lit, latest, fetch, tocfa, incr, comma, exit

   ;; Increment tos
   defword "1+", incr
   dd    lit, 1, plus, exit

   defword "1-", decr
   dd    lit, 1, minus, exit

   ;; Cell multiple
   defword "cell", cell
   dd    lit, 4, _times, exit

   ;; Increment by cell size
   defword "cell+", cellincr
   dd    lit, 1, cell, plus, exit

   defword "negate", negate
   dd    invert, incr, exit

   ;; Printing numbers for debugging
   defword "(emit-digit)", emit_digit
   dd    lit, 48, plus, emit, exit

   ;; Emit '-' and change the sign of the number if it's negative.
   defword "(?emit-minus)", pemit_minus
   dd    _dup, lzero, zbranch, @f, lit, 45, emit, negate
@@:
   dd    exit

   ;; : digits ( n -- )
   defword "(digits)", digits
   dd    _dup, zbranch, @f, lit, 10, divmod, digits, emit_digit, exit
@@:
   dd    drop, exit

   ;; Emit a carriage return.
   defword "cr", cr
   dd    lit, 10, emit, exit

   ;; Emit a number
   defword ".", dot
   dd    pdup, zbranch, @f, pemit_minus, digits, cr, exit
@@:
   dd    lit, 0, emit_digit, cr, exit

   ;; XXX: Couldn't get ." string literal to work in Fasm...
   defword ".str", printstring
   dd    _dup, fetchbyte, pdup, zbranch, @f
   dd    emit, incr, branch, printstring + 4
@@:
   dd    drop, cr, exit

   ;; : assert ( x -- ) \ end program if argument is zero
   defword "assert", _assert
   dd    zbranch, @f, exit
@@:
   dd    bye

   defword "?dup", pdup
   dd    _dup, zbranch, @f, _dup
@@:
   dd    exit

   defword "2dup", twodup
   dd    over, over, exit

   defword "2drop", twodrop
   dd    drop, drop, exit

   defword "nip", nip
   dd    swap, drop, exit

   defword "tuck", tuck
   dd    swap, over, exit

   ;; Append value to user memory at HERE.
   defword ",", comma
   dd    here, _store
   dd    here, cellincr, _dp, _store, exit

   defword "c,", bytecomma
   dd    here, storebyte
   dd    here, incr, _dp, _store, exit

   defword "align", _align
   dd    lit, 3, plus, lit, -4, _and, exit

   ;; Return the first byte past the end of string pointed by the input
   ;; address.
   ;; : strend ( a -- a' )
   defword "strend", strend
   dd    _dup, fetchbyte, zbranch, @f, incr, branch, strend+4
   ;; ("branch, strend+4" is meant to be tail recursion)
@@:
   dd    incr, exit

   ;; Get the name string of a dictionary address
   defword "dict>name", dict_name
   dd    cellincr, incr, exit   ; skip link pointer and flag byte

   ;; Go from dictionary entry to code field
   ;; : >cfa ( a -- a' )
   defword ">cfa", tocfa
   dd    dict_name, strend, _align, exit

   ;; Like >cfa, but skip to the first data field
   defword ">dfa", todfa
   dd    tocfa
   dd    cellincr
   dd    exit

   defword "2incr", twoincr
   dd    incr, swap, incr, swap, exit

   ;; a b cmp returns -1, 0 or 1 if a is smaller than, equal or larger than b.
   ;; : cmp ( a b -- ord )
   defword "cmp", _cmp
   dd    minus, _dup, zequ, zbranch, @f
   dd    drop, lit, 0, exit
@@:
   dd    lzero, zbranch, @f
   dd    lit, -1, exit
@@:
   dd    lit, 1, exit

   ;; cont? is true iff both c1 and c2 are equal and nonzero.
   ;; : (strcmp) ( c1 c2 -- ord cont? )
   defword "(strcmp)", aux_strcmp
   dd    twodup, _cmp, nrot, _and, _not, over, _or, _not, exit

   ;; This is basically the C strcmp.
   ;; : strcmp ( s1 s2 -- ord )
   defword "strcmp", strcmp
   dd    twodup, fetchbyte, swap, fetchbyte, swap, aux_strcmp, zbranch, @f
   dd    drop, twoincr, branch, strcmp + 4
@@:
   dd    nip, nip, exit

   ;; : (find) ( name dictptr -- a )
   defword "(find)", aux_find
   dd    _dup, _not, zbranch, @f, nip, exit
@@:
   dd    twodup, dict_name, strcmp, _not, zbranch, @f, nip, exit
@@:
   dd    fetch, branch, aux_find + 4

   ;; Find the address of a given word
   ;; : find ( name -- a )
   defword "find", find
   ;; The latest word. The address is the start of the dictionary entry, and
   ;; fetching from the address gets us the next word to search.
   dd    latest, fetch, aux_find, exit

   defconst "word-buffer", word_buffer, 0, WORD_BUFFER

   defword "bl?", blp
   dd    lit, 32, equ, exit

   defword "cr?", crp
   dd    lit, 10, equ, exit

   defword "eatblanks", eatblanks
   dd    key, _dup, blp, zbranch, @f, drop, branch, eatblanks + 4
@@:
   dd    exit

   ;; Add chars from stdin to buffer until you get a blank or a newline.
   ;; Then write terminating zero to buffer and exit.
   ;; : (word) ( addr c -- )
   defword "(word)", aux_word
   dd    _dup, blp, over, crp, _or, zbranch, @f
   dd    drop, lit, 0, swap, storebyte, exit ; Store end-of-string
@@:
   dd    over, storebyte, incr, key, branch, aux_word + 4

   defword "word", _word
   ;; TODO
   dd    eatblanks, lit, WORD_BUFFER, swap, aux_word, lit, WORD_BUFFER, exit

   ;; Add a digit to the number accumulator
   defword "(add-digit)", add_digit
   dd    swap, lit, 10, _times, plus

   ;; min <= n <= max
   ;; : between ( n min max -- ? )
   defword "between", between
   dd    rot, swap, over, swap  ;; min n n max
   dd    lte, nrot, lte, _and, exit

   defvar "(numbase)", numbase, 0, 10

   ;; : (digit) ( c -- n ok? )
   defword "(digit)", digit
   dd    _dup, lit, '0', lit, '9', between, zbranch, @f
   ;; Standard numeric digit, always ok.
   dd    lit, '0', minus, lit, -1, exit
@@:
   ;; Only proceed when parsing hex.
   dd    numbase, fetch, lit, 0x10, equ, _not, zbranch, @f
   dd    lit, 0, exit           ; Error
@@:
   dd    _dup, lit, 'a', lit, 'f', between, zbranch, @f
   dd    lit, 'W', minus, lit, -1, exit
@@:
   dd    _dup, lit, 'A', lit, 'F', between, zbranch, @f
   dd    lit, '7', minus, lit, -1, exit
@@:
   dd    lit, 0, exit           ; Error

   ;; : (readsign) ( a -- +1/-1 a' )
   ;; (Also sets base to 16 if starting with $)
   defword "(readsign)", readsign
   dd    lit, 10, numbase, _store ; Always assume base 10 by default.
   dd    _dup, fetchbyte, lit, '-', equ, zbranch, @f
   dd    incr, lit, -1, swap, exit ; Consume minus sign and leave -1 as multiplier.
@@:
   dd    _dup, fetchbyte, lit, '$', equ, zbranch, @f
   dd    lit, 0x10, numbase, _store, incr
@@:
   dd    lit, 1, swap, exit     ; No minus sign, leave 1 as multiplier.

   ;; : (buildnumber) ( acc a -- acc' a' )
   defword "(buildnumber)", buildnumber
   dd    _dup, fetchbyte, digit, zbranch, @f
   dd    rot, numbase, fetch, _times, plus ; S: a (n+acc*10)
   dd    swap, incr, branch, buildnumber + 4
@@:
   dd    drop, exit             ; Non-digit encontered, stop.

   ;; Parse a string into a number.
   ;; : >number ( a -- num ok? )
   defword ">number", tonumber
   dd    readsign               ; Add sign coefficient to stack
   dd    lit, 0, swap, buildnumber ; Add number to stack, pointer is where number stops
   dd    fetchbyte, zequ        ; OK flag
   dd    nrot, _times, swap     ; Apply sign.
   dd    exit

   ;; : strcpy ( src dest -- )
   defword "strcpy", strcpy
   dd    over, fetchbyte, _dup, zbranch, @f
   dd    over, storebyte, swap, incr, swap, incr, branch, strcpy + 4
@@:
   dd    swap, storebyte, drop, exit

   ;; : strlen ( a -- n )
   defword "strlen", strlen
   dd    lit, 0
@@:
   dd    over, fetchbyte, zbranch, @f
   dd    swap, incr, swap, incr, branch, @b
@@:
   dd    nip, exit

   ;; Create the start of a new word to HERE.
   ;; : create ( addr -- )
   defword "create", create
   ;; Write value of LATEST at HERE and store the value of
   ;; HERE before this as the new LATEST value.
   dd    here, latest, fetch, comma, latest, _store
   ;; XXX: Not bothering with lenghts, still need this for flags
   dd    lit, 0, bytecomma
   dd    _dup, here, strcpy
   dd    strlen, lit, 1, plus, here, plus, _align, _dp, _store
   dd    exit

   defconst "docol", _docol, 0, docol

   ;; Switch to immediate mode
   defword "[", lbrac, FLAG_IMMEDIATE
   dd    lit, 0, state, _store, exit

   ;; Switch to compile mode
   defword "]", rbrac
   dd    lit, 1, state, _store, exit

   defword ":", colon
   dd    _word, create          ; Get the new word and create it
   dd    lit,  docol, comma     ; Append docol
   ;; dd latest, fetch, hidden  ; TODO: Make word hidden
   dd    rbrac, exit            ; Go to compile mode and exit

   defword ";", semicolon, FLAG_IMMEDIATE
   dd    lit, exit, comma       ; Append exit word to the word being compiled.
   ;; dd latest, fetch, hidden  ; TODO: Make word unhidden
   dd    lbrac                  ; Go back to immediate mode
   dd    exit

   ;; Toggle immediate flag on latest word
   defcode "immediate", immediate, FLAG_IMMEDIATE
   mov   edi, [var_latest]
   add   edi, 4
   xor   [edi], byte FLAG_IMMEDIATE
   NEXT

   defword "immediate?", immediatep
   dd    cellincr, fetch, lit, FLAG_IMMEDIATE, _and, exit

   defword "'", quote, FLAG_IMMEDIATE
   dd    lit, lit, comma, _word, find, tocfa, comma, exit

   ;; Interpreter executing (0) or compiling (nonzero)
   defvar "state", state, 0, 0

   defword "(interpret-error)", interpret_error
   ;; XXX: This is horrible. Get some actual string handling in somehow.
   dd    lit, 'R', lit, 'R', lit, 'E', emit, emit, emit, cr
   dd    exit

   ;; : (interpret-word) ( a -- )
   ;; dup >cfa swap immediate? if execute exit then
   ;; state @ if , exit then execute ;
   defword "(intepret-word)", interpret_word
   dd    _dup, tocfa, swap, immediatep, zbranch, @f
   dd    execute, exit
@@:
   dd    state, fetch, zbranch, @f, comma, exit
@@:
   dd    execute, exit

   ;; Compile number as literal if in compile state, otherwise just no-op to
   ;; keep it in stack for execute mode.
   defword "(interpret-number)", interpret_number
   dd    state, fetch, zbranch, @f, lit, lit, comma, comma
@@:
   dd    exit

   defword "interpret", interpret
   dd    _word, _dup, find, pdup, zbranch, @f ; Jump to number parse if not found as word.
   dd    nip, interpret_word, exit
@@:
   dd    tonumber, zbranch, @f, interpret_number, exit
@@:
   dd    interpret_error, exit

   defword "quit", quit
   dd    interpret, branch, quit + 4

   ;; First free byte in data heap
   defvar "dp", _dp, 0, 0

   defword "here", here
   dd    _dp, fetch, exit

   ;; Top of the parameter stack
   defvar "s0", s0, 0, 0

   ;; The latest word defined. THIS MUST BE THE LAST KERNEL WORD DEFINED for
   ;; the value to list all kernel words.
   defvar "latest", latest, 0, name_latest

init_heap:
   mov   eax, 45                ; BRK syscall for growing the data segment
   xor   ebx, ebx               ; call it with 0 to get the data segment start
   int   0x80
   mov   [HEAP_BOT], eax        ; store the heap start
   mov   [var__dp], eax         ; also set the HERE constant to this.
   add   eax, INIT_HEAP         ; Now grow the data segment to INIT_HEAP size
   mov   ebx, eax
   mov   eax, 45
   int   0x80
   ret

INIT_HEAP = 65536
HEAP_BOT: dd 0
HEAP_TOP: dd 0

   ;; Reserved buffers

INPUT_BUFFER: rb 256            ; for stdin

WORD_BUFFER_SIZE = 32
WORD_BUFFER: rb WORD_BUFFER_SIZE ; for reading words

RETURN_STACK: rb 8192
RETURN_STACK_TOP:
