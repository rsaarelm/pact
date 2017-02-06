format binary
use32
thumb

org     0x08000000

RAM_START = 0x20000000
RAM_LENGTH = 8192

    dw RAM_START + RAM_LENGTH
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
    nop
    b reset

error:
    nop
    b error
