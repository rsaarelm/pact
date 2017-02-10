@ r0
@ r1
@ r2
@ r3
@ r4
@ r5            Pact next instruction pointer   (NIP)
@ r6            Pact return stack pointer       (RSP)
@ r7        avoid, ARM uses this for system calls
@ r8
@ r9        avoid, ARM may have special uses
@ r10
@ r11
@ r12       avoid, ARM uses thes for intra-procedure calls
@ r13:  sp  ARM stack pointer
@ r14:  lr  ARM link register, holds return address from Branch with Link
@ r15:  pc  ARM program counter

RAM_START = 0x20000000
RAM_LENGTH = 8192

@ Compile-time variable for setting up memory regions
_region_pos = RAM_START + RAM_LENGTH

@ for memory region REGION in RAM, define symbols REGION_START, REGION_LENGTH and REGION_END
.macro ram_region name, size
    \name\()_LENGTH = \size
    \name\()_END = _region_pos
    _region_pos = _region_pos - \size
    \name\()_START = _region_pos
.endm

ram_region RETURN_STACK, 256
ram_region WORD_BUFFER, 32

STACK_TOP = _region_pos

@ Vector table
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

@ The NEXT macro ends machine code words by jumping to the next threaded code position.
.macro NEXT
    ldr r0, [r5, #4]            @ Load next instruction to r0, increment NIP
    ldr r1, [r0]                @ Memory at NIP is jump address, deref into r1
    bx r1                       @ Jump to address
.endm

@ Push to return stack
.macro PUSH_RSP reg
    sub r6, #4
    str \reg, [r6]
.endm

@ Pop from return stack
.macro POP_RSP reg
    ldr \reg, [r6]
    add r6, #4
.endm

.global _start
_start:
    ldr r6, =RETURN_STACK_END       @ Initialize RSP
    adr r0, pact_boot               @ Load initial word
    b docol

@ Inner interpreter for threaded Pact bytecode
@ NEXT jumps here, assume r0 will contain the current code word address
docol:
    PUSH_RSP r5                     @ Store next instruction on return stack
    ldr r5, [r0, #4]                @ Word after codeword -> NIP
    NEXT

@ Test word, TODO: Better stuff.
pact_boot:
    .long code_pact_boot
code_pact_boot:
    nop
    b code_pact_boot
