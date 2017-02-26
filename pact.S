# Special registers used by the Pact interpreter:
NIP .req r7  @ Next instruction pointer
RSP .req r6  @ Return stack pointer (return stack is separate from the data stack)
TOS .req r5  @ Top-of-stack register

STACK_UNDERFLOW = 0x5EEB100D    @ Magic number at the bottom of stack

# TODO: Put VM stuff, docol, NEXT etc, in a separate include file
# TODO: Name lookup, make use of the flag values
# TODO: Add a linker file for memory regions and interrupt vector

RAM_START = 0x20000000
RAM_LENGTH = 8192

# Compile-time variable for setting up memory regions
_region_pos = RAM_START + RAM_LENGTH

# for memory region REGION in RAM, define symbols REGION_START, REGION_LENGTH and REGION_END
.macro ram_region name, size
    \name\()_LENGTH = \size
    \name\()_END = _region_pos
    _region_pos = _region_pos - \size
    \name\()_START = _region_pos
.endm

ram_region RETURN_STACK, 256
ram_region WORD_BUFFER, 32

STACK_TOP = _region_pos

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
.macro word_header name, sym, flags=0
# The argument to .align is an exponent of 2, not byte number?
# Looks like .align 2 gets me 4-byte word boundary then.
.align 2
name_\sym:
    .long _latest_word          @ Back pointer to previous.
    .byte \flags
    .asciz "\name"
.align 2
\sym:

# Assign this word to the latest word chain
_latest_word = name_\sym
.endm

# Define a native code word
.macro defcode name, sym, flags=0
    word_header \name, \sym, \flags
    .long 1f + 1                @ Jump to code in next word in Thumb mode
1:
.endm

# Define an interpreted word
.macro defword name, sym, flags=0
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
    ldr RSP, =RETURN_STACK_END       @ Initialize RSP
    ldr TOS, =STACK_UNDERFLOW
    ldr r0, =boot                    @ Load initial word
    ldr NIP, =boot + 4
    b docol

.ltorg

# Inner interpreter for threaded Pact bytecode
# NEXT jumps here, assume r0 will contain the current code word address
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
.align 2
name_equals:
    .long _latest_word          @ Back pointer to previous.
    .byte 0
    .asciz "="
.align 2
_latest_word = name_equals
equals:
    .long 1f + 1                @ Jump to code in next word in Thumb mode
# Code begins:
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
defcode "zbranch", zbranch
    TOS_POP r0
    cmp r0, #0
    bne 1f
    ldr r0, [NIP]
    add NIP, r0
    NEXT
1:
    add NIP, #4         @ Jump over the branch address
    NEXT

################################ Hardware stuff

# TODO Rewrite in Pact once we get the REPL going
# This is pretty awful as is.
defcode "init-hw", init_hw
    ldr r0, =0x40004400 @ USART2
    mov r1, #0b1101     @ Usart c1 bits
    str r1, [r0]
    add r0, #0xC        @ Baud rate
    ldr r1, =833        @ 8e6 (STM32 clock Hz) / 9600 bps
    str r1, [r0]

    NEXT

# Emit char to serial-out
# : emit ( char -- )
defcode "emit" emit
    ldr r0, =0x40004400 @ USART2
    add r0, #28         @ isr
# Busy-wait until ISR clears send
1:
    ldr r1, [r0]
    mov r2, #0x80
    and r1, r2
    cmp r1, #0x80
    bne 1b
    add r0, #12         @ tdr
    str TOS, [r0]       @ Write TOS value and consume
    pop {TOS}
    NEXT

# Return char and true or false depending on if key is available in serial input
# : key? ( -- c T | F )
defcode "key?" key_p
    ldr r0, =0x40004400 @ USART2
    add r0, #28         @ isr
    ldr r1, [r0]
    mov r2, #0x20
    and r1, r2
    cmp r1, #0x20
    bne 1f              @ No key, jump away
    add r0, #8          @ rdr
    ldr r1, [r0]        @ Load key, push to stack
    TOS_PUSH r1
    push {TOS}          @ Put T flag to TOS
    mov TOS, #0
    sub TOS, #1
    NEXT
1:                      @ No key
    mov r1, #0          @ Put F flag to TOS
    TOS_PUSH r1
    NEXT

# Wait for key input.
defword "key", key
1:
    .long key_p, zbranch, 1b - ., exit

.ltorg

.include "bootstrap.S"
