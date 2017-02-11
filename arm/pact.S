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

.ltorg

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
# Hardware test
    .long init_hw, lit, 0x40, emit, lit, 0x42, emit
    .long led_on
# Test math and stack.
    .long lit, 10, lit, 3, minus, lit, 3, over, plus, lit, 2, times, swap, minus
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

# : drop ( x -- )
defcode drop, drop
    TOS_POP r0
    NEXT

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

# : not ( x -- !x )
defcode not, not
    cmp TOS, #0
    bne 1f
    sub TOS, #1     @ Make it -1 = 0xffffffff
    NEXT
1:
    mov TOS, #0     @ zero any non-zero
    NEXT

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

################################ Flow control

# Jump NIP to address in the cell next to the 'branch' one.
defcode branch, branch
    ldr NIP, [NIP]
    NEXT

# If top of stack is 0, do a branch
defcode zbranch, zbranch
    TOS_POP r0
    cmp r0, #0
    bne 1f
    ldr NIP, [NIP]
    NEXT
1:
    add NIP, #4         @ Jump over the branch address
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
# This is pretty awful as is.
defcode init-hw, init_hw
    ldr r0, =0x40021000 @ RCC
    add r0, #0x14          @ Start GPIOA clock
    ldr r1, [r0]
    mov r2, #1
    lsl r2, #17
    orr r1, r2
    str r1, [r0]

    add r0, #0x8           @ Start USART2 clock
    ldr r1, [r0]
    mov r2, #1
    lsl r2, #17
    orr r1, r2
    str r1, [r0]

    ldr r0, =0x48000000 @ GPIOA

    ldr r1, [r0]        @ Mode
    mov r2, #0b11       @ P5, LED: Output
    lsl r2, #10
    add r2, #0b11110000
    bic r1, r2

    mov r2, #1
    lsl r2, #10
    add r2, #0b10100000 @ P2, P3, alternate
    orr r1, r2

    str r1, [r0]

    add r0, #0x4
    ldr r1, [r0]
    mov r2, #0b101100    @ P2, P3, P5: pushpull
    bic r1, r2
    str r1, [r0]

    add r0, #0x4        @ P2, P3, P5 high speed
    ldr r1, [r0]
    mov r2, #0x3
    lsl r2, #6
    add r2, #0xf
    lsl r2, #4
    orr r1, r2
    str r1, [r0]

    add r0, #0x4        @ P2, P3, P5 pullup-neither
    ldr r1, [r0]
    mov r2, #0x3
    lsl r2, #6
    add r2, #0xf
    lsl r2, #4
    bic r1, r2
    str r1, [r0]

    add r0, #0x14       @ P2, P3 alternate function
    ldr r1, [r0]
    mov r2, #0xff
    lsl r2, #8
    bic r1, r2
    mov r2, #0x11
    lsl r2, #8
    orr r1, r2
    str r1, [r0]

    ldr r0, =0x40004400 @ USART2
    mov r1, #0b1101     @ Usart c1 bits
    str r1, [r0]
    add r0, #0xC        @ Baud rate
    ldr r1, =833        @ 8e6 (STM32 clock Hz) / 9600 bps
    str r1, [r0]

    NEXT

# Emit char to serial-out
# : emit ( char -- )
defcode emit emit
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
# XXX: Looks like I can't make a macro parameter be "key?".
defcode key-p key_p
    ldr r0, =0x40004400 @ USART2
    add r0, #28         @ isr
    ldr r1, [r0]
    mov r2, #0x80
    and r1, r2
    cmp r1, #0x80
    bne 1f
    add r0, #8          @ rdr
    ldr r1, [r0]
    TOS_PUSH r1
    mov r1, #0
    push {TOS}
    neg TOS, r1
    NEXT
1:                      @ No key
    mov r1, #0
    TOS_PUSH r1
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
