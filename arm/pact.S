# Special registers used by the Pact interpreter:
TOS .req r4  @ Top-of-stack register
NIP .req r5  @ Next instruction pointer
RSP .req r6  @ Return stack pointer (return stack is separate from the data stack)

STACK_UNDERFLOW = 0x5EEB100D    @ Magic number at the bottom of stack

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

.global _start
_start:
    ldr RSP, =RETURN_STACK_END       @ Initialize RSP
    ldr TOS, =STACK_UNDERFLOW
    ldr r0, =pact_boot               @ Load initial word
    ldr NIP, =code_pact_boot
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

# Test word, TODO: Better stuff.
.align 4
pact_boot:
    .long docol + 1
code_pact_boot:
    .long lit
    .long 1
    .long lit
    .long 2
    .long add
    .long exit

# Add two stack values
.align 4
add:
    .long add_code + 1
add_code:
    TOS_POP r0
    add TOS, r0
    push {r1}
    NEXT

# Save the next word to stack as literal
.align 4
lit:
    .long lit_code + 1
lit_code:
    ldr r1, [NIP]
    TOS_PUSH r1
    add NIP, #4     @ The literal wasn't a command, advance NIP past it
    NEXT
