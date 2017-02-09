format binary
use32
thumb

org     0x08000000

RAM_START = 0x20000000
RAM_LENGTH = 8192

RCC = 0x40021000
GPIOA = 0x48000000

; r0
; r1
; r2
; r3
; r4
; r5
; r6
; r7        avoid, ARM uses this for system calls
; r8
; r9        avoid, ARM may have special uses
; r10           Pact next instruction pointer   (NIP)
; r11           Pact return stack pointer       (RSP)
; r12       avoid, ARM uses thes for intra-procedure calls
; r13:  sp  ARM stack pointer
; r14:  lr  ARM link register, holds return address from Branch with Link
; r15:  pc  ARM program counter


; NEXT ends every machine code word by jumping to the next threaded position.
macro NEXT {
    ldr r0, [r10], #4   ; Load next instruction to R0, increment NIP
    ldr r1, [r0]        ; Load next instruction address to R1
    bx  r1
}

; Push to return stack
macro PUSHRSP reg {
    str reg, [r11, #-4]!    ; Store register to *(RSP - 4), decrement RSP
}

; Pop from return stack
macro POPRSP reg {
    ldr reg, [r11], #4      ; Load from RSP, increment RSP
}

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; Code


    dw RAM_START + RAM_LENGTH ; Stack pointer
    dw reset + 1
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

reset:
    nop
    b reset

error:
    nop
    b error

;; Inner interpreter for threaded Pact bytecode
;; NEXT jumps here, so R0 will contain what we're running now.
docol:
    PUSHRSP r10     ; Store next instruction on return stack
    add r10, r0, #4 ; Make NIP the next word from the code word.
    NEXT            ; Execute the word
