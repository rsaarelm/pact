format binary
thumb
; This is the spec for Cortex-M0. Maybe.
processor CPU32_V4T + CPU32_V5T + CPU32_V6T + CPU32_ALIGN + CPU32_6M


org     0x08000000

RAM_START = 0x20000000
RAM_LENGTH = 8192

; Compile-time variable for setting up memory regions
_region_pos = RAM_START + RAM_LENGTH

; for region REGION, define symbols REGION_START, REGION_LENGTH and REGION_END
macro ram_region name, size
{
    name#_LENGTH = size
    name#_END = _region_pos
    _region_pos = _region_pos - size
    name#_START = _region_pos
}

ram_region RETURN_STACK, 256

; Buffer for constructing words
ram_region WORD_BUFFER, 32

STACK_TOP = _region_pos

RCC = 0x40021000
GPIOA = 0x48000000

; r0
; r1
; r2
; r3
; r4
; r5            Pact next instruction pointer   (NIP)
; r6            Pact return stack pointer       (RSP)
; r7        avoid, ARM uses this for system calls
; r8
; r9        avoid, ARM may have special uses
; r10
; r11
; r12       avoid, ARM uses thes for intra-procedure calls
; r13:  sp  ARM stack pointer
; r14:  lr  ARM link register, holds return address from Branch with Link
; r15:  pc  ARM program counter


; NEXT ends every machine code word by jumping to the next threaded position.
macro NEXT {
    ldr r0, [r5]        ; Load next instruction to R0, increment NIP
    adds r5, 4
    ldr r1, [r0]        ; Load next instruction address to R1
    bx  r1
}

; Push to return stack
macro PUSHRSP reg {
    subs r6, 4
    str reg, [r6]
}

; Pop from return stack
macro POPRSP reg {
    ldr reg, [r6]          ; Load from RSP, increment RSP
    adds r6, 4
}

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; Code


    dw STACK_TOP ; Stack pointer
    dw start + 1
    dw error + 1
    dw error + 1
    dw error + 1
    dw error + 1
    dw error + 1
    dw error + 1
    dw error + 1
    dw error + 1
    dw error + 1
    dw error + 1
    dw error + 1
    dw error + 1
    dw error + 1
    dw error + 1

align 2
error:
    b error

align 2
start:
    ; Init return stack
    ; XXX: Is there a nicer way to get the constant here than to use the
    ; intermediate mem addr?
    ldr r6, [return_stack_end]
    ; Init r0, as if we'd have called NEXT
    adr r0, pact_boot
    ; Jump to inner interpreter, using r0 value as the start word.
    b docol
align 4
return_stack_end: dw RETURN_STACK_END

align 2
pact_boot:
    dw $ + 4 + 1  ; Code word.
    ; TODO: Stuff here
    nop
    nop
    b pact_boot

align 2
;; Inner interpreter for threaded Pact bytecode
;; NEXT jumps here, so R0 will contain what we're running now.
docol:
    PUSHRSP r5      ; Store next instruction on return stack
    adds r5, r0, #4 ; Make NIP the next word from the code word.
    NEXT            ; Execute the word

; vim:syntax=fasm
