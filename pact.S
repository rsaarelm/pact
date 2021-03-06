# Special registers used by the Pact interpreter:
NIP .req r7  @ Next instruction pointer
RSP .req r6  @ Return stack pointer (return stack is separate from the data stack)
TOS .req r5  @ Top-of-stack register

STACK_UNDERFLOW = 0x5EEB100D    @ Magic number at the bottom of stack

# TODO: Put VM stuff, docol, NEXT etc, in a separate include file
# TODO: Name lookup, make use of the flag values
# TODO: Add a linker file for memory regions and interrupt vector

RAM_START = 0x40000000
RAM_LENGTH = 8192

RETURN_STACK_END = RAM_START + 0x100

STACK_TOP = RAM_START + RAM_LENGTH

LAST_VAR_ADDR = RAM_START + 0x180
HERE_VAR_ADDR = RAM_START + 0x184
LAST_IMMEDIATE_VAR_ADDR = RAM_START + 0x188
IS_COMPILING_VAR_ADDR = RAM_START + 0x18C

# Vector table
.long   STACK_TOP
.long   _start + 1
.long   _err + 1
.long   _err + 1
.long   _err + 1
.long   _err + 1
.long   _err + 1
.long   _err + 1
.long   _err + 1
.long   _err + 1
.long   _err + 1
.long   _err + 1
.long   _err + 1
.long   _err + 1
.long   _err + 1
.long   _err + 1

_err:
    b _err

# The NEXT macro ends machine code words by jumping to the next threaded code position.
.macro NEXT
    ldr r0, [NIP]               @ Next codeword address from NIP to r0
    add NIP, #4                 @ Increment NIP
    ldr r1, [r0]                @ Dereference codeword address
    bx r1                       @ Jump to address
.endm

# Push to return stack
.macro PUSH_RSP reg
    sub RSP, #4
    str \reg, [RSP]
.endm

# Pop from return stack
.macro POP_RSP reg
    ldr \reg, [RSP]
    add RSP, #4
.endm

# Push TOS, move reg to TOS
.macro TOS_PUSH reg
    push {TOS}
    mov TOS, \reg
.endm

# Move TOS to reg, pop into TOS
.macro TOS_POP reg
    mov \reg, TOS
    pop {TOS}
.endm

# Backpointer to the last word defined at compile time
_latest_word = 0

FLAG_IMMEDIATE_WORD = 0x80  @ Immediate words are executed at word definition time
FLAG_HIDDEN_WORD = 0x20     @ Hidden words are not returned during word lookup

# Build a word header
# name: The string name used in Pact code, can be any ascii text without whitespace
# sym: The symbol used in assembly, must be a valid symbol for the assembler,
#      otherwise should be same as name
# flags: Bitmask for immediate word or hidden word
#
# Used as part of defcode and defword macros, do not use directly.
.macro word_header name, sym, flags=0x80
# The argument to .align is an exponent of 2, not byte number?
# Looks like .align 2 gets me 4-byte word boundary then.
.align 2, 0
name_\sym:
    .long _latest_word          @ Back pointer to previous.
    .byte \flags
    .asciz "\name"
.align 2, 0
\sym:

# Assign this word to the latest word chain
_latest_word = name_\sym
.endm

# Define a native code word
.macro defcode name, sym, flags=0x80
    word_header \name, \sym, \flags
    .long 1f + 1                @ Jump to code in next word in Thumb mode
1:
.endm

# Define an interpreted word
.macro defword name, sym, flags=0x80
    word_header \name, \sym, \flags
    .long docol + 1
.endm

.macro defconst name, sym, value
    defcode \name, \sym
    ldr r0, =\value
    TOS_PUSH r0
    NEXT
.endm

.global _start
_start:
    # Global variables init
    ldr r0, =name_last
    ldr r1, =LAST_VAR_ADDR
    str r0, [r1]

    ldr r0, =0x40000200
    ldr r1, =HERE_VAR_ADDR
    str r0, [r1]

    ldr r0, =0x0
    ldr r1, =LAST_IMMEDIATE_VAR_ADDR
    str r0, [r1]

    ldr r0, =0x0
    ldr r1, =IS_COMPILING_VAR_ADDR
    str r0, [r1]

    # Inner interpreter init
    ldr RSP, =RETURN_STACK_END       @ Initialize RSP
    ldr TOS, =STACK_UNDERFLOW
    ldr r0, =boot                    @ Load initial word
    ldr NIP, =boot + 4

    b docol

.ltorg

# Inner interpreter for threaded Pact bytecode
# NEXT jumps here, assume r0 will contain the current code word address
defcode "docol", docol_
docol:
    PUSH_RSP NIP                     @ Store next instruction on return stack
    add r0, #4
    mov NIP, r0                      @ Word after codeword -> NIP
    NEXT

################################ Memory operations

# Save the next word to stack as literal
defcode "lit", lit
    ldr r1, [NIP]
    TOS_PUSH r1
    add NIP, #4     @ The literal wasn't a command, advance NIP past it
    NEXT

# Read memory at address
# : @ ( addr -- value )
defcode "\@", fetch
    ldr TOS, [TOS]
    NEXT

# Write value to address
# : ! ( value addr -- )
defcode "!", store
    TOS_POP r0          @ The address
    str TOS, [r0]       @ Value from TOS
    TOS_POP r0          @ Drop value
    NEXT

# Read byte at address
# : c@ ( addr -- byte )
defcode "c\@", cfetch
    ldrb TOS, [TOS]
    NEXT

# Write byte to address
# : c! ( byte addr -- )
defcode "c!", cstore
    TOS_POP r0          @ The address
    strb TOS, [r0]      @ Value from TOS
    TOS_POP r0          @ Drop value
    NEXT

# Get data stack address
# : sp@ ( -- addr )
defcode "sp\@", spfetch
    TOS_PUSH r13
    NEXT

# Get data stack bottom address
# : sp0 ( -- addr )
defcode "sp0", sp0
    ldr r0, =STACK_TOP
    sub r0, #4
    TOS_PUSH r0
    NEXT

# Execute word from code address in stack
# : execute ( code-addr -- )
defcode "execute", execute
    TOS_POP r0
    ldr r1, [r0]
    bx r1               @ (never returns, no need for NEXT)

# Store word in return stack
# : >r ( x -- )
defcode ">r", tor
    TOS_POP r0
    PUSH_RSP r0
    NEXT

# Retrieve word from return stack
# : r> ( -- x )
defcode "r>", rto
    POP_RSP r0
    TOS_PUSH r0
    NEXT

################################ Stack juggling

# : drop ( x -- )
defcode "drop", drop
    TOS_POP r0
    NEXT

# : dup ( x -- x x )
defcode "dup", dup
    push {TOS}
    NEXT

# : swap ( x y -- y x )
defcode "swap", swap
    pop {r0}
    push {TOS}
    mov TOS, r0
    NEXT

# : over ( x y -- x y x )
defcode "over", over
    ldr r0, [SP]    @ Get second stack value, so first at *SP
    TOS_PUSH r0
    NEXT

# : rot ( x y z -- y z x )
defcode "rot", rot
    TOS_POP r0
    TOS_POP r1
    TOS_POP r2
    TOS_PUSH r1
    TOS_PUSH r0
    TOS_PUSH r2
    NEXT

# : pick ( x0 ... xn n -- x0 .. xn x0 )
defcode "pick", pick
    mov r0, SP      @ Top of data stack
    mov r1, #4
    mul TOS, r1     @ Multiply count by word length to get mem offset
    add r0, TOS     @ Fetch stack value to TOS
    ldr TOS, [r0]
    NEXT

################################ Logic and arithmetic

# : xor ( x y -- x^y )
defcode "xor", xor
    TOS_POP r0
    eor TOS, r0
    NEXT

# : or ( x y -- x|y )
defcode "or", or
    TOS_POP r0
    orr TOS, r0
    NEXT

# : and ( x y -- x&y )
defcode "and", and_
    TOS_POP r0
    and TOS, r0
    NEXT

# : <0 ( x -- x<0 )
defcode "<0", ltz
    cmp TOS, #0
    blt 1f
    mov TOS, #0
    NEXT            @ TOS is 0, false
1:
    mov TOS, #0
    sub TOS, #1     @ Make TOS -1, true
    NEXT

# : = ( x y -- x=y )
# XXX: Have to write out the defcode because can't pass '=' as param.
.align 2, 0
name_equals:
    .long _latest_word          @ Back pointer to previous.
    .byte 0
    .asciz "="
.align 2, 0
_latest_word = name_equals
equals:
    .long 1f + 1                @ Jump to code in next word in Thumb mode
# Code begins:
1:
    TOS_POP r0
    cmp TOS, r0
    beq 1f
    mov TOS, #0
    NEXT
1:
    mov TOS, #0
    sub TOS, #1
    NEXT

# : + ( x y -- x+y )
defcode "+", plus
    TOS_POP r0
    add TOS, r0
    NEXT

# : - ( x y -- x-y )
defcode "-", minus
    TOS_POP r0
    sub TOS, r0
    NEXT

# : * ( x y -- xy )
defcode "*", times
    TOS_POP r0
    mul TOS, r0
    NEXT

# : lshift ( x y -- x<<y )
defcode "lshift", lshift
    TOS_POP r0
    lsl TOS, r0
    NEXT

# : rshift ( x y -- x>>y )
defcode "rshift", rshift
# XXX: Is this going to fail if shift length is 0? If so, need to add a check
# here for 0
    TOS_POP r0
    lsr TOS, r0
    NEXT

################################ Flow control

# Exit a Pact word
defcode "exit", exit
    POP_RSP NIP
    NEXT

# Offset NIP by the address in the cell after the 'branch' one.
defcode "branch", branch
    ldr r0, [NIP]
    add NIP, r0
    NEXT

# If top of stack is 0, do a branch
defcode "0branch", zbranch
    TOS_POP r0
    cmp r0, #0
    bne 1f
    ldr r0, [NIP]
    add NIP, r0
    NEXT
1:
    add NIP, #4         @ Jump over the branch address
    NEXT

.ltorg

.include "bootstrap.S"

.ltorg

# This is high-level code that would otherwise go in the bootstrap module, but
# it needs to quote the LIT word, and word quoting isn't a part of the
# bootstrap repertoire.
defword "handle-number", handle_number
    .long is_compiling_p
    .long zbranch
    .long 1f - .
    .long lit
# And here comes the tricky bit, indistinguishable from the previous LIT word
# that's an actual executed code. The second LIT is instead the value that gets
# pushed to stack.
    .long lit
# And then written to where the compiled code is being generated.
    .long comma
# And then we write the actual number from stack as well.
    .long comma
1:
# Otherwise just leave the number for stack, we're in interpret mode.
    .long exit

defcode "here", here
    ldr r0, =HERE_VAR_ADDR
    TOS_PUSH r0
    NEXT

defcode "last-immediate", last_immediate
    ldr r0, =LAST_IMMEDIATE_VAR_ADDR
    TOS_PUSH r0
    NEXT

defcode "is-compiling", is_compiling
    ldr r0, =IS_COMPILING_VAR_ADDR
    TOS_PUSH r0
    NEXT

# Defined here so it's guaranteed to be the actual last kernel word
defcode "last", last
    ldr r0, =LAST_VAR_ADDR
    TOS_PUSH r0
    NEXT
