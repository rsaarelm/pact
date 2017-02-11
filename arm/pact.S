# Special registers used by the Pact interpreter:
NIP .req r7  @ Next instruction pointer
RSP .req r6  @ Return stack pointer (return stack is separate from the data stack)
TOS .req r5  @ Top-of-stack register

STACK_UNDERFLOW = 0x5EEB100D    @ Magic number at the bottom of stack

# TODO: Led blinker demo
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
    ldr r0, =pact_boot               @ Load initial word
    ldr NIP, =pact_boot + 4
    b docol

# Inner interpreter for threaded Pact bytecode
# NEXT jumps here, assume r0 will contain the current code word address
docol:
    PUSH_RSP NIP                     @ Store next instruction on return stack
    add r0, #4
    mov NIP, r0                      @ Word after codeword -> NIP
    NEXT

# Exit a Pact word
exit:
    POP_RSP NIP
    NEXT

defword boot, pact_boot
    .long init_hw
    .long led_on
    .long lit
    .long 10
    .long lit
    .long 3
    .long minus
    .long lit
    .long 3         @ 7 3
    .long over      @ 7 3 7
    .long plus      @ 7 10
    .long lit
    .long 2
    .long times    @ 7 20
    .long swap     @ 20 7
    .long minus    @ 13
    .long exit

################################ Memory operations

# Save the next word to stack as literal
defcode lit, lit
    ldr r1, [NIP]
    TOS_PUSH r1
    add NIP, #4     @ The literal wasn't a command, advance NIP past it
    NEXT

# Read memory at address
# : @ ( addr -- value )
defcode \@, fetch
    ldr TOS, [TOS]
    NEXT

# Write value to address
# : ! ( value addr -- )
defcode !, store
    TOS_POP r0          @ The value
    str r0, [TOS]       @ Address is at TOS
    TOS_POP r0          @ Drop address
    NEXT

################################ Stack juggling

# : dup ( x -- x x )
defcode dup, dup
    push {TOS}
    NEXT

# : swap ( x y -- y x )
defcode swap, swap
    pop {r0}
    push {TOS}
    mov TOS, r0
    NEXT

# : over ( x y -- x y x )
defcode over, over
    ldr r0, [SP]    @ Get second stack value, so first at *SP
    TOS_PUSH r0
    NEXT

################################ Logic and arithmetic

# : or ( x y -- x|y )
defcode or, or
    TOS_POP r0
    orr TOS, r0
    NEXT

# : + ( x y -- x+y )
defcode +, plus
    TOS_POP r0
    add TOS, r0
    NEXT

# : - ( x y -- x-y )
defcode -, minus
    TOS_POP r0
    sub TOS, r0
    NEXT

# : * ( x y -- xy )
defcode *, times
    TOS_POP r0
    mul TOS, r0
    NEXT

################################ Hardware stuff

defconst rcc rcc 0x40021000
defconst gpioa gpioa 0x48000000

# I want to be able to say "rcc port-a enable" and get bit 17 toggled at rcc + 14.
# Already defined the base address at rcc, and "enable" looks pretty generic,
# so "port-a" needs to do some work here.

# : clock-gpio-a ( base-addr -- addr bit ) 20 + $20000 ;
defword clock-gpio-a, clock_gpio_a
    .long lit
    .long 20
    .long plus      @ Offset from RCC base
    .long lit
    .long 0x20000   @ Bit offset to toggle
    .long exit

# XXX: This is too specific
# : enable ( addr bitmask -- ) over @ or swap !
#   ( Set bit at memory addr to 1. )
defword enable, enable
    .long over
    .long fetch
    .long or
    .long swap
    .long store
    .long exit

# TODO Rewrite in Pact once we get the REPL going
defcode init-hw, init_hw
    ldr r0, =0x40021000 @ RCC
    add r0, #0x14
    ldr r1, [r0]
    mov r2, #1
    lsl r2, #17
    orr r1, r2          @ Start GPIOA clock
    str r1, [r0]

    ldr r0, =0x48000000 @ GPIOA
    ldr r1, [r0]        @ Pin P5 mode Output
    mov r2, #3
    lsl r2, #10
    bic r1, r2
    mov r2, #1
    lsl r2, #10
    orr r1, r2
    str r1, [r0]

    add r0, #0x4        @ P5 PushPull
    ldr r1, [r0]
    mov r2, #1
    lsl r2, #5
    bic r1, r2
    str r1, [r0]

    add r0, #0x4        @ P5 high speed
    ldr r1, [r0]
    mov r2, #3
    lsl r2, #10
    orr r1, r2
    str r1, [r0]

    add r0, #0x4        @ P5 pullup-neither
    ldr r1, [r0]
    mov r2, #3
    lsl r2, #10
    bic r1, r2
    str r1, [r0]

    NEXT

# TODO: Use a parameter instead of hardcoding both on and off.
defcode led-on led_on
    ldr r0, =0x48000000 @ GPIOA
    add r0, #0x18
    mov r1, #0x20
    str r1, [r0]
    NEXT

defcode led-off led_off
    ldr r0, =0x48000000 @ GPIOA
    add r0, #0x18
    mov r1, #0x20
    lsl r1, #16
    str r1, [r0]
    NEXT
